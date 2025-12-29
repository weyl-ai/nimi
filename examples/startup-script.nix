# This package seems to be used as the testbed for development of Modular Services in `nixpkgs`
{ lib, ... }:
{
  perSystem =
    { pkgs, self', ... }:
    {
      checks.startupScript = self'.packages.nimi.mkNimiBin {
        settings.startup.runOnStartup = lib.getExe (
          pkgs.writeShellApplication {
            name = "example-startup-script";
            text = ''
              echo "hello world"
            '';
          }
        );
      };
    };
}
