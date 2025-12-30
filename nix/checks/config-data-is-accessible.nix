{ lib, ... }:
{
  perSystem =
    { pkgs, self', ... }:
    let
      accessesConfig = pkgs.writeShellApplication {
        name = "accesses-config";
        runtimeInputs = [
          pkgs.coreutils
        ];
        text = ''
          cat "$XDG_CONFIG_HOME/sample-config.txt"
        '';
      };

      nimiWrapper = self'.packages.nimi.mkNimiBin {
        services."accesses-config" = {
          process.argv = [
            (lib.getExe accessesConfig)
          ];
          configData."sample-cfg" = {
            enable = true;
            text = ''
              hello world
            '';
            path = "sample-config.txt";
          };
        };
        settings.restart.mode = "never";
      };
    in
    {
      checks.configDataIsAccessible = pkgs.runCommandLocal "config-data-is-accessible" { } ''
        set -euo pipefail

        nimi_logs="$(${lib.getExe nimiWrapper} 2>&1)"

        if [[ "$nimi_logs" != *"hello world"* ]]; then
          echo "Failed to find config file contents ('hello world') inside logs"
          echo "nimi logs: $nimi_logs"
          exit 1
        fi

        echo "Successfully found 'hello world' inside logs"
        mkdir "$out"
      '';
    };
}
