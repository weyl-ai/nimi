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

          settings = evaluatedConfig.config.settings.container;

          cleanedSettings =
            if settings.fromImage == null then builtins.removeAttrs settings [ "fromImage" ] else settings;
        in
        inputs'.nix2container.packages.nix2container.buildImage (
          {
            config.entrypoint = [
              (lib.getExe (config.mkNimiBin module))
            ];
          }
          // cleanedSettings
        );
    };

}
