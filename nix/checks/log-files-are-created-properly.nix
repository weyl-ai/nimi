{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  perSystem =
    { pkgs, self', ... }:
    let
      serviceModule =
        { config, ... }:
        {
          options.printString = mkOption {
            description = ''
              String to print in test logs
            '';
            type = types.str;
          };

          config.process.argv = [
            (lib.getExe (
              pkgs.writeShellApplication {
                name = "string-printer";
                text = ''
                  echo "${config.printString}"
                '';
              }
            ))
          ];
        };

      nimiWrapper = self'.packages.nimi.mkNimiBin {
        services."service-a" = {
          imports = [ serviceModule ];
          printString = "Hello from service A";
        };
        services."service-b" = {
          imports = [ serviceModule ];
          printString = "Hello from service B";
        };
        settings.restart.mode = "never";
        settings.logging = {
          enable = true;
          logsDir = "my_logs";
        };
      };
    in
    {
      checks.logFilesAreCreatedProperly = pkgs.runCommandLocal "log-files-are-created-properly" { } ''
        set -euo pipefail

        echo "${lib.getExe nimiWrapper}"
        ${lib.getExe nimiWrapper}

        a_logs="$(cat my_logs/logs-0/service-a.txt)"
        if [ "Hello from service A" != "$a_logs" ]; then
          echo "Got incorrect output from service A"
          echo "Contents: $a_logs"
          exit 1
        fi

        b_logs="$(cat my_logs/logs-0/service-b.txt)"
        if [ "Hello from service B" != "$b_logs" ]; then
          echo "Got incorrect output from service B"
          echo "Contents: $b_logs"
          exit 1
        fi

        echo "Successfully found all service log files with correct contents"
        mkdir "$out"
      '';
    };
}
