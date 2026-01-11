{ nix2container, ... }:
let
  failedToEvaluateHomePkgsError = "while generating nimi home manager packages:";
  failedToEvaluateHomeServicesError = "while generating nimi home manager services:";
in
{
  lib,
  config,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption types;
  inherit (pkgs.stdenv.hostPlatform) system;

  nimi = pkgs.callPackage ../package.nix {
    inherit (nix2container.packages.${system}) nix2container;
  };
in
{
  _class = "home-manager";

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
        Install.WantedBy = [ "default.target" ];

        Unit = {
          Description = "Nimi Service";
          After = [ "default.target" ];
          PartOf = [ "default.target" ];
        };

        Service = {
          ExecStart = lib.getExe pkg;
          Restart = "always";
          RestartSec = "10";
        };
      }) nimiPkgs;
    in
    {
      home.packages = builtins.addErrorContext failedToEvaluateHomePkgsError (
        builtins.attrValues nimiPkgs
      );

      systemd.user.services = builtins.addErrorContext failedToEvaluateHomeServicesError nimiServices;
    };
}
