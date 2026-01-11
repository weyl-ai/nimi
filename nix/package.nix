{
  rustPlatform,
  lib,
  clippy,
  runCommandLocal,
  jq,
  writeShellApplication,
  dockerTools,
  pkgs,
  nix2container ? null,
  ...
}@pkgArgs:
let
  errorCtxs = {
    failedToEvaluateNimiModule = "while evaluating nimi module set:";
    failedToEvaluateNimiContainer = "while evaluating nimi OCI container configuration:";
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

  defaultNimiModule = lib.modules.importApply ./modules/nimi.nix { inherit pkgs; };

  cargoToml = fromTOML (builtins.readFile ../Cargo.toml);
in
rustPlatform.buildRustPackage (
  finalAttrs:
  let
    evalNimiModule =
      module:
      builtins.addErrorContext errorCtxs.failedToEvaluateNimiModule
        (lib.evalModules {
          modules = [
            defaultNimiModule
            module
          ];
          specialArgs = { inherit pkgs; };
          class = "nimi";
        }).config;

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
            finalAttrs.finalPackage
          ];
        }
        ''
          ln -sf "${formattedJSON}" "$out"

          nimi --config "${formattedJSON}" validate
        '';

    mkNimiBin =
      module:
      let
        evaluatedConfig = evalNimiModule module;
        cfgJson = toNimiJson evaluatedConfig;
      in
      builtins.addErrorContext errorCtxs.failedToCreateNimiWrapper (writeShellApplication {
        name = evaluatedConfig.settings.binName;
        runtimeInputs = [ finalAttrs.finalPackage ];
        text = ''
          exec nimi --config "${cfgJson}" run "$@"
        '';
        inherit (evaluatedConfig) passthru meta;
      });

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
            pkgArgs.nix2container.buildImage
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
  in
  {
    pname = cargoToml.package.name;
    inherit (cargoToml.package) version;

    src = lib.fileset.toSource {
      root = ../.;
      fileset = lib.fileset.unions [
        ../Cargo.lock
        ../Cargo.toml
        ../src
      ];
    };

    cargoLock.lockFile = ../Cargo.lock;

    nativeBuildInputs = [ clippy ];

    preBuild = ''
      cargo clippy -- -D warnings
    '';

    meta = {
      description = "Tini-like PID 1 for containers and target for NixOS modular services";
      homepage = "https://github.com/weyl-ai/nimi";
      license = lib.licenses.mit;
      maintainers = [ lib.maintainers.baileylu ];
      mainProgram = "nimi";
    };

    passthru = {
      inherit
        mkNimiBin
        mkContainerImage
        evalNimiModule
        toNimiJson
        ;
    };
  }
)
