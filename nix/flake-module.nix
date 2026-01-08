{ lib, self, ... }:
let
  nimiInput = self;

  failedToEvaluateNimiPkgsError = "while generating nimi packages:";
  failedToEvaluateNimiChecksError = "while generating nimi checks:";

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
          default = { };
        };
      };

      config.perSystem =
        { config, system, ... }:
        let
          nimi = nimiInput.packages.${system}.default;

          generatedNimiPkgs = lib.pipe config.nimi [
            (lib.mapAttrsToList (
              name: module:
              let
                overwrittenName = {
                  imports = [ module ];
                  settings.binName = lib.mkDefault name;
                };
              in
              {
                "${name}-service" = nimi.mkNimiBin overwrittenName;
                "${name}-container" = nimi.mkContainerImage overwrittenName;
              }
            ))
            lib.mergeAttrsList
          ];
        in
        {
          packages = builtins.addErrorContext failedToEvaluateNimiPkgsError generatedNimiPkgs;
          checks = builtins.addErrorContext failedToEvaluateNimiChecksError generatedNimiPkgs;
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
