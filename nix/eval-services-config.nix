{
  flake-parts-lib,
  inputs,
  ...
}:
let
  inherit (inputs) nixpkgs;
  inherit (nixpkgs) lib;
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
      lib = pkgs.lib;

      nimiModule = {
        options.services = mkOption {
          description = ''
            Services to run inside the nimi runtime
          '';
          type = types.attrsOf (
            types.submoduleWith {
              class = "service";
              modules = [ (lib.modules.importApply "${inputs.nixpkgs}/nixos/modules/system/service/portable/service.nix" { inherit pkgs; }) ];
              specialArgs = {
                inherit pkgs;
              };
            }
          );
          default = { };
          visible = "shallow";
        };
      };
    in
    {
      evalServicesConfig =
        module:
        let
          evaluatedConfig = lib.evalModules {
            modules = [
              nimiModule
              module
            ];
            class = "service";
          };

          inputJSON = builtins.toJSON evaluatedConfig.config;

          validatedJSON =
            pkgs.runCommandLocal "nimi-config-validated.json"
              {
                nativeBuildInputs = [ self'.packages.nimi ];
              }
              ''
                cat > "$out" <<EOF
                ${inputJSON}
                EOF

                nimi --config "$out" validate
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
