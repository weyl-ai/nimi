let
  failedToEvaluateNixOSPkgsError = "while generating nimi nixos packages:";
  failedToEvaluateNixOSServicesError = "while generating nimi nixos services:";
in
{
  lib,
  config,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption types;
  nimi = pkgs.callPackage ../package.nix { };
in
{
  _class = "nixos";

  options.nimi = mkOption {
    description = ''
      Configuration for Nimi, a process manager/runner for [NixOS Modular Services](https://nixos.org/manual/nixos/unstable/#modular-services).

      This configuration can also be used to run services locally in a devshell and to build containers, all from
      the same services configuration.
    '';
    type = types.lazyAttrsOf types.raw;
    default = { };
  };

  config =
    let
      nimiPkgs = lib.pipe config.nimi [
        (lib.mapAttrsToList (
          name: module: {
            "${name}" = nimi.mkNimiBin {
              imports = [ module ];
              settings.binName = lib.mkDefault name;
            };
          }
        ))
        lib.mergeAttrsList
      ];

      nimiServices = lib.mapAttrs (_name: pkg: {
        enable = true;
        after = [ "default.target" ];
        wantedBy = [ "default.target" ];
        description = "Nimi Service";
        serviceConfig = {
          Type = "simple";
          ExecStart = lib.getExe pkg;
          Restart = "always";
          RestartSec = "10";
        };
      }) nimiPkgs;
    in
    {
      environment.systemPackages = builtins.addErrorContext failedToEvaluateNixOSPkgsError (
        builtins.attrValues nimiPkgs
      );

      systemd.services = builtins.addErrorContext failedToEvaluateNixOSServicesError nimiServices;
    };
}
