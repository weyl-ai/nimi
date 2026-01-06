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
    options.evalServicesConfig = mkOption {
      description = ''
        Function for generating a configured Nimi instance
      '';
      type = types.functionTo types.package;
    };
  };

  config.perSystem =
    { self', pkgs, ... }:
    let
      inherit (pkgs) lib;
    in
    {
      evalServicesConfig =
        module:
        let
          evaluatedConfig = lib.evalModules {
            modules = [
              self.modules.nimi.default
              module
            ];
            specialArgs = { inherit pkgs; };
            class = "nimi";
          };

          inputJSON = builtins.toJSON evaluatedConfig.config;

          formattedJSON =
            pkgs.runCommandLocal "nimi-config-formatted.json"
              {
                nativeBuildInputs = [
                  pkgs.jq
                ];
              }
              ''
                jq . <<'EOF' > "$out"
                ${inputJSON}
                EOF
              '';

          validatedJSON =
            pkgs.runCommandLocal "nimi-config-validated.json"
              {
                nativeBuildInputs = [
                  self'.packages.nimi
                ];
              }
              ''
                ln -sf "${formattedJSON}" "$out"

                nimi --config "${formattedJSON}" validate
              '';
        in
        pkgs.writeShellApplication {
          name = "nimi";
          runtimeInputs = [ self'.packages.nimi ];
          text = ''
            exec nimi --config "${validatedJSON}" run "$@"
          '';
        };
    };

}
