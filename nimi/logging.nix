{ lib, ... }:
let
  inherit (lib) mkOption mkEnableOption types;
in
{
  _class = "nimi";

  options.settings.logging = mkOption {
    description = ''
      Logging behavior for the nimi process manager.

      This section controls if per-service log files are written during a run.
      When enabled, each service writes to its own file under the configured
      logs directory.

      Log files are created at runtime and live in a run-specific subdirectory
      under `logsDir` (for example `logs-0/service-a.txt`). Each line from the
      service stdout or stderr is appended to the same file, preserving
      execution order as best as possible.
    '';
    example = lib.literalExpression ''
      {
        enable = true;
        logsDir = "my_logs";
      }
    '';
    type = types.submodule {
      options = {
        enable = mkEnableOption ''
          If per-service log files should be written to `settings.logging.logsDir`.

          When disabled, log output still streams to stdout/stderr but no files
          are created.
        '';
        logsDir = mkOption {
          description = ''
            Directory to create and write per-service logs to.

            Nimi creates a `logs-<n>` subdirectory inside this path at runtime
            and writes one file per service.
          '';
          type = types.str;
          default = "nimi_logs";
        };
      };
    };
    default = { };
  };
}
