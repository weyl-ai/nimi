{ inputs, ... }:
let
  inherit (inputs) nixpkgs import-tree;
  inherit (nixpkgs) lib; # The standalone `lib` flake does not have `meta.maintainers`
  inherit (lib) mkOption types;
in
{
  flake.modules.nimi.default =
    { pkgs, ... }:
    let
      servicesModule =
        lib.modules.importApply "${nixpkgs}/nixos/modules/system/service/portable/service.nix"
          {
            inherit pkgs;
          };
    in
    {
      _class = "nimi";

      options.services = mkOption {
        description = ''
          Services to run inside the nimi runtime
        '';
        type = types.attrsOf (
          types.submoduleWith {
            class = "service";
            modules = [
              servicesModule
            ];
          }
        );
        default = { };
        visible = "shallow";
      };

      imports = [
        (import-tree ../nimi)
      ];
    };
}
