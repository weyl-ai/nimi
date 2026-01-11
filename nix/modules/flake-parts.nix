{ nix2container, ... }:
let
  failedToEvaluateNimiPkgsError = "while generating nimi packages:";
  failedToEvaluateNimiChecksError = "while generating nimi checks:";
in
{ lib, flake-parts-lib, ... }:
let
  inherit (flake-parts-lib) mkPerSystemOption;
  inherit (lib) mkOption types;
in
{
  _class = "flake";

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
    {
      config,
      pkgs,
      system,
      ...
    }:
    let
      nimi = pkgs.callPackage ../package.nix {
        inherit (nix2container.packages.${system}) nix2container;
      };

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
}
