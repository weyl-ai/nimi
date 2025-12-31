{ lib, ... }:
let
  inherit (lib) mkOption mkEnableOption types;
in
{
  options.settings.logging = mkOption {
    description = ''
      Logging behavior for the nimi process manager.

      TODO
    '';
    type = types.submodule {
      options = {
        enable = mkEnableOption ''
          If files for each services' logs should be written to `settings.logging.logsDir`
        '';
        logsDir = mkOption {
          description = ''
            Directory to (create and) write per service logs to

            Happens at runtime
          '';
          type = types.str;
          default = "nimi_logs";
        };
      };
    };
    default = { };
  };
}
