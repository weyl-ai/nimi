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
    options.mkNimiBin = mkOption {
      description = ''
        Function for generating a configured Nimi instance
      '';
      type = types.functionTo types.package;
    };
  };

  config.perSystem =
    {
      self',
      pkgs,
      config,
      ...
    }:
    {
      mkNimiBin =
        module:
        let
          evaluatedConfig = config.evalNimiModule module;
          cfgJson = config.toNimiJson evaluatedConfig;
        in
        pkgs.writeShellApplication {
          name = "nimi";
          runtimeInputs = [ self'.packages.nimi ];
          text = ''
            exec nimi --config "${cfgJson}" run "$@"
          '';
          inherit (evaluatedConfig.config) passthru meta;
        };
    };

}
