{ lib, flake-parts-lib, ... }:
let
  inherit (flake-parts-lib) mkPerSystemOption;
  inherit (lib) mkOption types;
in
{
  options.perSystem = mkPerSystemOption {
    options.mkWrapper = mkOption {
      description = ''
        Function for generating a configured Nimi instance
      '';
      type = types.functionTo types.package;
    };
  };

  config.perSystem =
    { self', pkgs, ... }:
    {
      mkWrapper =
        modules:
        let
          evaluatedConfig = lib.evalModules {
            inherit modules;
            class = "service";
          };

          inputJSON = builtins.toJSON evaluatedConfig.config;

          configFile = builtins.toFile "nimi-config.json" inputJSON;
        in
        pkgs.writeShellApplication {
          name = "nimi";
          runtimeInputs = [ self'.packages.nimi ];
          text = ''
            exec nimi --config "${configFile}" "$@"
          '';
        };
    };

}
