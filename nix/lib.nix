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
    failedToEvaluateNimiBwrap = "while evaluating nimi bubblewrap configuration:";
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
    Build a wrapper binary from an already-evaluated nimi config. This writes
    a validated JSON config and emits a shell wrapper that runs `nimi` with
    that config so consumers can execute it like a normal binary.

    Use this when you already have an evaluated config (e.g., from `evalNimiModule`)
    and want to avoid re-evaluating the module.

    # Example

    ```nix
    let cfg = evalNimiModule { settings.binName = "my-nimi"; };
    in mkNimiBinWithConfig cfg
    ```

    # Type

    ```
    mkNimiBinWithConfig :: AttrSet -> Derivation
    ```

    # Arguments

    evaluatedConfig
    : An already-evaluated nimi config (output of `evalNimiModule`).
  */
  mkNimiBinWithConfig =
    evaluatedConfig:
    let
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
    Build a wrapper binary for a given nimi module. This evaluates the module,
    writes a validated JSON config, and emits a shell wrapper that runs `nimi`
    with that config so consumers can execute it like a normal binary.

    This is a convenience wrapper around `mkNimiBinWithConfig` that handles
    module evaluation for you.

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
  mkNimiBin = module: mkNimiBinWithConfig (evalNimiModule module);

  /**
    Build a container image from an already-evaluated nimi config. This wires
    the container entrypoint to the wrapper binary and uses
    `nix2container.buildImage` when available (otherwise `dockerTools.buildImage`).

    Use this when you already have an evaluated config (e.g., from `evalNimiModule`)
    and want to avoid re-evaluating the module.

    # Example

    ```nix
    let cfg = evalNimiModule { settings.binName = "my-nimi"; };
    in mkContainerImageWithConfig cfg
    ```

    # Type

    ```
    mkContainerImageWithConfig :: AttrSet -> Derivation
    ```

    # Arguments

    evaluatedConfig
    : An already-evaluated nimi config (output of `evalNimiModule`).
  */
  mkContainerImageWithConfig =
    evaluatedConfig:
    let
      cleanedSettings = lib.pipe evaluatedConfig.settings.container [
        (settings: if settings.fromImage == null then removeAttrs settings [ "fromImage" ] else settings)
        (settings: removeAttrs settings [ "imageConfig" ])
      ];

      imageCfg = evaluatedConfig.settings.container.imageConfig // {
        entrypoint = [
          (lib.getExe (mkNimiBinWithConfig evaluatedConfig))
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
    Build a container image for a given nimi module. This evaluates the module,
    wires the container entrypoint to the wrapper binary, and uses
    `nix2container.buildImage` when available (otherwise `dockerTools.buildImage`).

    This is a convenience wrapper around `mkContainerImageWithConfig` that handles
    module evaluation for you.

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
  mkContainerImage = module: mkContainerImageWithConfig (evalNimiModule module);

  /**
    Build a sandboxed wrapper using bubblewrap from an already-evaluated nimi config.
    This creates a nimi binary and wraps it in a bubblewrap sandbox configured via
    `settings.bubblewrap` options.

    Use this when you already have an evaluated config (e.g., from `evalNimiModule`)
    and want to avoid re-evaluating the module.

    The sandbox is configured through the module system with sensible defaults:
    - `/nix/store` and `/sys` are read-only bound
    - `/etc/resolv.conf` is bound with `--ro-bind-try` (skipped if missing)
    - `/nix`, `/tmp`, `/run`, `/var`, `/etc` are tmpfs mounts
    - `/dev` and `/proc` are bound
    - Network is shared but user/pid/uts/ipc/cgroup namespaces are unshared

    # Example

    ```nix
    let cfg = evalNimiModule {
      settings.binName = "my-sandboxed-app";
      settings.bubblewrap.unshare.pid = true;
    };
    in mkBwrapWithConfig cfg
    ```

    # Type

    ```
    mkBwrapWithConfig :: AttrSet -> Derivation
    ```

    # Arguments

    evaluatedConfig
    : An already-evaluated nimi config (output of `evalNimiModule`).
  */
  mkBwrapWithConfig =
    evaluatedConfig:
    let
      bin = mkNimiBinWithConfig evaluatedConfig;
      cfg = evaluatedConfig.settings.bubblewrap;
    in
    builtins.addErrorContext errorCtxs.failedToEvaluateNimiBwrap (writeShellApplication {
      name = "${bin.name}-sandbox";
      runtimeInputs = [ bubblewrap ];
      text = ''
        exec bwrap \
          ${lib.escapeShellArgs cfg.flags} \
          -- ${lib.getExe bin} "$@"
      '';

      inherit (evaluatedConfig) passthru;
      meta = evaluatedConfig.meta // {
        badPlatforms = (evaluatedConfig.meta.badPlatforms or [ ]) ++ lib.platforms.darwin;
      };
    });

  /**
    Build a sandboxed wrapper using bubblewrap for a given nimi module.
    This evaluates the module, creates a nimi binary, and wraps it in a
    bubblewrap sandbox configured via `settings.bubblewrap` options.

    This is a convenience wrapper around `mkBwrapWithConfig` that handles
    module evaluation for you.

    The sandbox is configured through the module system with sensible defaults:
    - `/nix/store` and `/sys` are read-only bound
    - `/etc/resolv.conf` is bound with `--ro-bind-try` (skipped if missing)
    - `/nix`, `/tmp`, `/run`, `/var`, `/etc` are tmpfs mounts
    - `/dev` and `/proc` are bound
    - Network is shared but user/pid/uts/ipc/cgroup namespaces are unshared

    # Example

    ```nix
    mkBwrap {
      settings.binName = "my-sandboxed-app";
      settings.bubblewrap = {
        environment.MY_VAR = "value";
        roBinds = [
          { src = "/nix/store"; dest = "/nix/store"; }
          { src = "/data"; dest = "/data"; }
        ];
        tmpfs = [ "/tmp" "/run" ];
        chdir = "/app";
        unshare.pid = true;
      };
    }
    ```

    # Type

    ```
    mkBwrap :: AttrSet -> Derivation
    ```

    # Arguments

    module
    : A nimi module attrset. Configure the sandbox via `settings.bubblewrap`.
  */
  mkBwrap = module: mkBwrapWithConfig (evalNimiModule module);
}
