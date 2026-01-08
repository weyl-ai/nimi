{
  flake-parts-lib,
  lib,
  ...
}:
let
  inherit (flake-parts-lib) mkPerSystemOption;
  inherit (lib) mkOption types;

  failedToEvaluateNimiContainerError = "while evaluating nimi OCI container configuration:";
in
{
  options.perSystem = mkPerSystemOption {
    options.mkContainerImage = mkOption {
      description = ''
        Create a ready to use OCI image from
        nimi config
      '';
      type = types.functionTo types.package;
    };
  };

  config.perSystem =
    { inputs', config, ... }:
    {
      mkContainerImage =
        module:
        let
          evaluatedConfig = config.evalNimiModule module;

          cleanedSettings = lib.pipe evaluatedConfig.settings.container [
            (settings: if settings.fromImage == null then removeAttrs settings [ "fromImage" ] else settings)
            (settings: removeAttrs settings [ "imageConfig" ])
          ];

          imageCfg = evaluatedConfig.settings.container.imageConfig // {
            entrypoint = [
              (lib.getExe (config.mkNimiBin module))
            ];
          };

          imageArgs = cleanedSettings // {
            config = imageCfg;
          };

          image = inputs'.nix2container.packages.nix2container.buildImage imageArgs;
        in
        builtins.addErrorContext failedToEvaluateNimiContainerError (
          image.overrideAttrs (oldAttrs: {
            passthru = (oldAttrs.passthru or { }) // evaluatedConfig.passthru;
            meta = (oldAttrs.meta or { }) // evaluatedConfig.meta;
          })
        );
    };

}
