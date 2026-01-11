{
  testers,
  lib,
  cowsay,
}:
testers.runNixOSTest {
  name = "test-nimi-nixos";
  nodes.machine = {
    imports = [
      ../modules/nixos.nix
    ];

    users.users.testUser = {
      isNormalUser = true;
    };

    nimi."test-nixos-module" = {
      services."cowsay" = {
        process.argv = [
          (lib.getExe cowsay)
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
}
