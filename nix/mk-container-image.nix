{
  flake-parts-lib,
  lib,
  ...
}:
let
  inherit (flake-parts-lib) mkPerSystemOption;
  inherit (lib) mkOption types;
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

          cleanedSettings = lib.pipe evaluatedConfig.config.settings.container [
            (settings: if settings.fromImage == null then removeAttrs settings [ "fromImage" ] else settings)
            (settings: removeAttrs settings [ "imageConfig" ])
          ];
        in
        (inputs'.nix2container.packages.nix2container.buildImage (
          {
            config = evaluatedConfig.config.settings.container.imageConfig // {
              entrypoint = [
                (lib.getExe (config.mkNimiBin module))
              ];
            };
          }
          // cleanedSettings
        )).overrideAttrs
          (oldAttrs: {
            passthru = (oldAttrs.passthru or { }) // evaluatedConfig.config.passthru;
            meta = (oldAttrs.meta or { }) // evaluatedConfig.config.meta;
          });
    };

}
