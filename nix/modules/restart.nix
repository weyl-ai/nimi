{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  _class = "nimi";

  options.settings.restart = mkOption {
    description = ''
      Restart policy for the nimi process manager.

      Use this to control if and how services are restarted after they exit.
      This is the main safety net for keeping long-running services alive, and
      also a guardrail to prevent tight restart loops from burning CPU.

      You can choose a policy that matches the reliability needs of each
      deployment. For development you might disable restarts entirely, while
      production workloads usually benefit from a bounded or always-on policy.
    '';
    example = lib.literalExpression ''
      {
        mode = "up-to-count";
        time = 500;
        count = 3;
      }
    '';
    type = types.submodule {
      options = {
        mode = mkOption {
          description = ''
            Selects the restart behavior.

            - `never`: do not restart failed services.
            - `up-to-count`: restart up to `count` times, then stop.
            - `always`: always restart on failure.

            Choose `up-to-count` if you want a service to get a few retries
            during a transient failure, but still fail fast when the issue is
            persistent. Choose `always` when continuous availability matters
            more than surfacing the failure.
          '';
          default = "always";
          example = lib.literalExpression ''"up-to-count"'';
          type = types.enum [
            "never"
            "up-to-count"
            "always"
          ];
        };
        time = mkOption {
          description = ''
            Delay between restarts in milliseconds.

            Increase this value for crash loops to give the system time to
            recover resources or for dependent services to come back.
          '';
          type = types.ints.positive;
          default = 1000;
          example = lib.literalExpression "250";
        };
        count = mkOption {
          description = ''
            Maximum number of restart attempts when `mode` is `up-to-count`.

            Once this limit is reached, the service is left stopped until you
            intervene or change the configuration.
          '';
          type = types.ints.positive;
          default = 5;
          example = lib.literalExpression "3";
        };
      };
    };
    default = { };
  };
}
