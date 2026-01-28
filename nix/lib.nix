{
  lib,
  pkgs,
  runCommandLocal,
  jq,
  nimi,
  nix2container ? null,
  dockerTools,
  writeShellApplication,
  bubblewrap,
}:
let
  errorCtxs = {
    failedToEvaluateNimiModule = "while evaluating nimi module set:";
    failedToEvaluateNimiContainer = "while evaluating nimi OCI container configuration:";
    failedToEvaluateNimiMicroVM = "while evaluating nimi microvm configuration:";
    failedToCreateNimiWrapper = "while evaluating nimi wrapper script:";
    failedConversionToJSON = "while serializing nimi config to json:";
  };

  warnings = {
    noNix2containerArg = ''
      `nix2container` was not provided as an input to the `nimi` package.

      Hence, `pkgs.dockerTools.buildImage` will be used instead of
      `nix2container.buildImage`. You may run into unexpected errors
      and/or generate larger containers than otherwise.

      Try passing `nix2container` to `nimi` (or use the flake):

      ```nix
      nimi = import <nimi> { inherit nix2container; };
      ```
    '';
    ignoredAttrsBecauseofNix2containerWarning = attrs: ''
      The following container attributes are ignored because `nix2container`
      has not been passed:

      ${builtins.toJSON attrs}
    '';
  };
in
rec {
  /**
    Evaluate a nimi module and return its config. This runs the module set
    through `lib.evalModules` with the nimi module included so you get the
    fully merged, validated configuration output.

    # Example

    ```nix
    evalNimiModule {
      settings.binName = "my-nimi";
    }
    ```

    # Type

    ```
    evalNimiModule :: AttrSet -> AttrSet
    ```

    # Arguments

    module
    : A nimi module attrset.
  */
  evalNimiModule =
    module:
    builtins.addErrorContext errorCtxs.failedToEvaluateNimiModule
      (lib.evalModules {
        modules = [
          ./modules/nimi.nix
          module
        ];
        specialArgs = { inherit pkgs; };
        class = "nimi";
      }).config;

  /**
    Render an evaluated config to validated JSON. The config is serialized,
    formatted with `jq`, then validated by running `nimi --config ... validate`
    so the resulting file is both pretty-printed and schema-checked.

    # Example

    ```nix
    let cfg = evalNimiModule { settings.binName = "my-nimi"; };
    in toNimiJson cfg
    ```

    # Type

    ```
    toNimiJson :: AttrSet -> Path
    ```

    # Arguments

    evaluatedConfig
    : The evaluated nimi config.
  */
  toNimiJson =
    evaluatedConfig:
    let
      inputJSON = builtins.addErrorContext errorCtxs.failedConversionToJSON (
        builtins.toJSON evaluatedConfig
      );

      formattedJSON =
        runCommandLocal "nimi-config-formatted.json"
          {
            nativeBuildInputs = [
              jq
            ];
          }
          ''
            jq . <<'EOF' > "$out"
            ${inputJSON}
            EOF
          '';

    in
    runCommandLocal "nimi-config-validated.json"
      {
        nativeBuildInputs = [
          nimi
        ];
      }
      ''
        ln -sf "${formattedJSON}" "$out"

        nimi --config "${formattedJSON}" validate
      '';

  /**
    Build a wrapper binary for a given nimi module. This evaluates the module,
    writes a validated JSON config, and emits a shell wrapper that runs `nimi`
    with that config so consumers can execute it like a normal binary.

    # Example

    ```nix
    mkNimiBin { settings.binName = "my-nimi"; }
    ```

    # Type

    ```
    mkNimiBin :: AttrSet -> Derivation
    ```

    # Arguments

    module
    : A nimi module attrset.
  */
  mkNimiBin =
    module:
    let
      evaluatedConfig = evalNimiModule module;
      cfgJson = toNimiJson evaluatedConfig;
    in
    builtins.addErrorContext errorCtxs.failedToCreateNimiWrapper (writeShellApplication {
      name = evaluatedConfig.settings.binName;
      runtimeInputs = [ nimi ];
      text = ''
        exec nimi --config "${cfgJson}" run "$@"
      '';
      inherit (evaluatedConfig) passthru meta;
    });

  /**
    Build a container image for a given nimi module. This evaluates the module,
    wires the container entrypoint to the wrapper binary, and uses
    `nix2container.buildImage` when available (otherwise `dockerTools.buildImage`).

    # Example

    ```nix
    mkContainerImage { settings.binName = "my-nimi"; }
    ```

    # Type

    ```
    mkContainerImage :: AttrSet -> Derivation
    ```

    # Arguments

    module
    : A nimi module attrset.
  */
  mkContainerImage =
    module:
    let
      evaluatedConfig = evalNimiModule module;

      cleanedSettings = lib.pipe evaluatedConfig.settings.container [
        (settings: if settings.fromImage == null then removeAttrs settings [ "fromImage" ] else settings)
        (settings: removeAttrs settings [ "imageConfig" ])
      ];

      imageCfg = evaluatedConfig.settings.container.imageConfig // {
        entrypoint = [
          (lib.getExe (mkNimiBin module))
        ];
      };

      imageArgs = cleanedSettings // {
        config = imageCfg;
      };

      hasNixToContainer = nix2container != null;

      buildImage =
        if hasNixToContainer then
          nix2container.buildImage
        else
          lib.warn warnings.noNix2containerArg dockerTools.buildImage;

      minimalArgSet =
        if hasNixToContainer then
          imageArgs
        else
          let
            attrsToRemove = [
              "layers"
              "maxLayers"
              "perms"
              "initializeNixDatabase"
            ];
          in
          lib.warn (warnings.ignoredAttrsBecauseofNix2containerWarning attrsToRemove) (
            removeAttrs imageArgs attrsToRemove
          );

      image = buildImage minimalArgSet;
    in
    builtins.addErrorContext errorCtxs.failedToEvaluateNimiContainer (
      image.overrideAttrs (oldAttrs: {
        passthru = (oldAttrs.passthru or { }) // evaluatedConfig.passthru;
        meta = (oldAttrs.meta or { }) // evaluatedConfig.meta;
      })
    );

  /**
    Run a bubblewrap instance for a given module. This evaluates the module,
    pops out a binary and wires it up to run inside a bubblewrap instance
    using the container from `mkContainerImage` as the root file system.

    # Example

    ```nix
    mkBwrap { settings.binName = "my-nimi"; }
    ```

    # Type

    ```
    mkBwrap :: AttrSet -> Derivation
    ```

    # Arguments

    module
    : A nimi module attrset.
  */
  mkBwrap =
    module:
    let
      evaluated = evalNimiModule module;
      bin = mkNimiBin module;
      image = evaluated.settings.container.imageConfig;

      rootfs = pkgs.symlinkJoin {
        name = "${bin.name}-rootfs";
        paths = [
          (pkgs.runCommand "bwrap-base-dirs" { } "mkdir -p $out/{nix,dev,proc,tmp,run,var,sys,etc}")
        ]
        ++ evaluated.settings.container.copyToRoot;
      };

      toEnvArg =
        envVarDef:
        lib.pipe envVarDef [
          (lib.splitString "=")
          lib.escapeShellArgs
          (args: "--setenv ${args}")
        ];

      envArgs = lib.concatMapStringsSep " " toEnvArg (image.Env or [ ]);

      volumeArgs = lib.concatMapStringsSep " " (p: "--tmpfs ${lib.escapeShellArg p}") (
        lib.attrNames (image.Volumes or { })
      );
    in
    builtins.addErrorContext errorCtxs.failedToEvaluateNimiMicroVM (writeShellApplication {
      name = "${bin.name}-sandbox";
      runtimeInputs = [ bubblewrap ];
      text = ''
        exec bwrap \
          --ro-bind ${rootfs} / \
          --tmpfs /nix \
          --ro-bind /nix/store /nix/store \
          --dev /dev \
          --proc /proc \
          --ro-bind /sys /sys \
          --tmpfs /tmp \
          --tmpfs /run \
          --tmpfs /var \
          --tmpfs /etc \
          --ro-bind /etc/resolv.conf /etc/resolv.conf \
          --chdir ${lib.escapeShellArg (image.WorkingDir or "/")} \
          --share-net \
          --unshare-user \
          --unshare-pid \
          --unshare-uts \
          --unshare-ipc \
          --unshare-cgroup \
          --die-with-parent \
          ${envArgs} \
          ${volumeArgs} \
          -- ${lib.getExe bin}
      '';
      meta.badPlatforms = lib.platforms.darwin;
    });
}
