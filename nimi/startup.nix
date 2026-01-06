{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.settings.startup = mkOption {
    description = ''
      Startup behavior for the nimi process manager.

      This section lets you run a one-time initialization command before any
      configured services are started. It is useful for bootstrapping state,
      preparing directories, or running a short setup task that should happen
      once per process manager start.

      The command is executed once and then the normal service startup proceeds.
      If you do not need a startup hook, leave it unset.
    '';
    example = lib.literalExpression ''
      {
        runOnStartup = /nix/store/abcd1234-my-init/bin/my-init;
      }
    '';
    type = types.submodule {
      options = {
        runOnStartup = mkOption {
          description = ''
            Path to a binary to run once at startup.

            This should be a single executable in the Nix store, not a shell
            snippet. Use `lib.getExe` to turn a package or derivation into a
            runnable path.

            The command runs before services start, so it is a good place to
            create files, check preconditions, or populate caches. If you need
            a long-running process, configure it as a service instead.

            Set to `null` to disable.
          '';
          type = types.nullOr types.pathInStore;
          default = null;
          example = lib.literalExpression ''
            lib.getExe (
              pkgs.writeShellApplication {
                name = "example-startup-script";
                text = '''
                  echo "hello world"
                ''';
              }
            )
          '';
        };
      };
    };
    default = { };
  };
}
