{ lib, self, ... }:
let
  nimiInput = self;

  flakeModule =
    { lib, flake-parts-lib, ... }:
    let
      inherit (flake-parts-lib) mkPerSystemOption;
      inherit (lib) mkOption types;
    in
    {
      options.perSystem = mkPerSystemOption {
        options.nimi = mkOption {
          description = ''
            Configuration for Nimi, a process manager/runner for [NixOS Modular Services](https://nixos.org/manual/nixos/unstable/#modular-services).

            This configuration can also be used to run services locally in a devshell and to build containers, all from
            the same services configuration.
          '';
          type = types.lazyAttrsOf types.raw;
        };
      };

      config.perSystem =
        { config, system, ... }:
        let
          nimi = nimiInput.packages.${system}.default;

          generatedNimiPkgs = lib.pipe config.nimi [
            (lib.mapAttrsToList (
              name: module: {
                "${name}-service" = nimi.mkNimiBin module;
                "${name}-container" = nimi.mkContainerImage module;
              }
            ))
            lib.mergeAttrsList
          ];
        in
        {
          packages = generatedNimiPkgs;
          checks = generatedNimiPkgs;
        };
    };
in
{
  imports = [
    flakeModule
  ];

  perSystem =
    { pkgs, ... }:
    {
      nimi."test-flake-module" = {
        services."cowsay" = {
          process.argv = [
            (lib.getExe pkgs.cowsay)
            "hi"
          ];
        };
      };
    };

  flake = {
    inherit flakeModule;
  };
}
