{
  flake-parts-lib,
  lib,
  self,
  ...
}:
let
  inherit (flake-parts-lib) mkPerSystemOption;
  inherit (lib) mkOption types;
in
{
  options.perSystem = mkPerSystemOption {
    options.evalNimiModule = mkOption {
      description = ''
        Function for evaluating a configured Nimi instance
      '';
      type = types.functionTo types.raw;
    };
  };

  config.perSystem =
    { pkgs, ... }:
    {
      evalNimiModule =
        module:
        lib.evalModules {
          modules = [
            self.modules.nimi.default
            module
          ];
          specialArgs = { inherit pkgs; };
          class = "nimi";
        };
    };
}
