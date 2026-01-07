{
  self,
  lib,
  ...
}:
let
  nimiInput = self;
in
{
  flake.nixosModules.default =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      inherit (lib) mkOption types;

      inherit (pkgs.stdenv.hostPlatform) system;
      nimi = nimiInput.packages.${system}.default;
    in
    {
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
          environment.systemPackages = builtins.attrValues nimiPkgs;

          systemd.services = nimiServices;
        };
    };

  perSystem =
    { pkgs, ... }:
    {
      checks.nimiNixOS = pkgs.testers.runNixOSTest {
        name = "test-nimi-nixos";
        nodes.machine = {
          imports = [
            self.nixosModules.default
          ];

          users.users.testUser = {
            isNormalUser = true;
          };

          nimi."test-nixos-module" = {
            services."cowsay" = {
              process.argv = [
                (lib.getExe pkgs.cowsay)
                "hi"
              ];
            };
          };
        };
        testScript = ''
          start_all()
          machine.wait_for_unit("multi-user.target")

          uid = machine.succeed("id -u testUser").strip()

          machine.wait_until_succeeds(
            "systemctl list-unit-files | grep -q \"^test-nixos-module\\.service\""
          )

          machine.succeed("systemctl start test-nixos-module.service")
          machine.wait_until_succeeds("! systemctl is-failed --quiet test-nixos-module.service")
          machine.wait_until_succeeds("journalctl -u test-nixos-module.service --no-pager -n 200 | grep -F \"hi\"")
        '';
      };
    };
}
