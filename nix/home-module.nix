{
  self,
  inputs,
  lib,
  ...
}:
let
  nimiInput = self;
in
{
  flake.homeModules.default =
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
          home.packages = builtins.attrValues nimiPkgs;

          systemd.user.services = nimiServices;
        };
    };

  perSystem =
    { pkgs, ... }:
    {
      checks.nimiHome = pkgs.testers.runNixOSTest {
        name = "test-nimi-home";
        nodes.homeMachine = {
          imports = [
            inputs.home-manager.nixosModules.default
          ];

          users.users.testUser = {
            isNormalUser = true;
          };

          home-manager.users.testUser = {
            imports = [
              self.homeModules.default
            ];
            nimi."test-home-module" = {
              services."cowsay" = {
                process.argv = [
                  (lib.getExe pkgs.cowsay)
                  "hi"
                ];
              };
            };

            home.stateVersion = "25.11";
          };
        };
        testScript = ''
          start_all()
          homeMachine.wait_for_unit("multi-user.target")

          uid = homeMachine.succeed("id -u testUser").strip()
          homeMachine.succeed("loginctl enable-linger testUser")
          homeMachine.succeed(f"systemctl start user@{uid}.service")

          def as_test_user(cmd: str) -> str:
            return "su - testUser -c 'export XDG_RUNTIME_DIR=/run/user/$(id -u); " + cmd + "'"

          homeMachine.wait_until_succeeds(
            as_test_user("systemctl --user list-unit-files | grep -q \"^test-home-module\\.service\"")
          )

          homeMachine.succeed(as_test_user("systemctl --user start test-home-module.service"))

          homeMachine.wait_until_succeeds(
            as_test_user("! systemctl --user is-failed --quiet test-home-module.service")
          )

          homeMachine.wait_until_succeeds(
            as_test_user("journalctl --user -u test-home-module.service --no-pager -n 200 | grep -F \"hi\"")
          )
        '';
      };
    };
}
