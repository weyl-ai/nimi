{ lib, config, ... }:
let
  inherit (lib) mkOption mkEnableOption types;

  cfg = config.settings.bubblewrap;
in
{
  _class = "nimi";

  options.settings.bubblewrap = mkOption {
    description = ''
      Configures nimi's builtin bubblewrap script generator.

      Note that none of these options will have any effect unless you are using
      `nimi.mkBwrap` to build your containers.
    '';
    type = types.submodule {
      options = {
        environment = mkOption {
          description = ''
            An attribute set of environment variables to set via
            `--setenv` in bubblewrap.
          '';
          type = types.lazyAttrsOf types.str;
          default = { };
        };
        roBinds = mkOption {
          description = ''
            Read only binds to allow access to in the
            bubblewrap instance.
          '';
          type = types.listOf (
            types.submodule {
              options.src = mkOption {
                description = ''
                  Source directory to allow access to in bubblewrap.
                '';
                type = types.str;
              };
              options.dest = mkOption {
                description = ''
                  Destination directory as it would appear inside bubblewrap.
                '';
                type = types.str;
              };
            }
          );
          default = [
            {
              src = "/nix/store";
              dest = "/nix/store";
            }
            {
              src = "/sys";
              dest = "/sys";
            }
            {
              src = "/etc/resolv.conf";
              dest = "/etc/resolv.conf";
            }
          ];
        };
        tmpfs = mkOption {
          description = ''
            Temporary filesystems to create in order to
            allow writing files inside bubblewrap
            that do not persist outside of the instance
          '';
          type = types.listOf types.str;
          default = [
            "/nix"
            "/tmp"
            "/run"
            "/var"
            "/etc"
          ];
        };
        extraTmpfs = mkOption {
          description = ''
            Extra temporary filesystems to concat
            to the default list
          '';
          type = types.listOf types.str;
          default = [ ];
        };
        bind = {
          dev = mkEnableOption "If /dev should be bound" // {
            default = true;
          };
          proc = mkEnableOption "If /proc should be bound" // {
            default = true;
          };
        };
        share.net = mkEnableOption "If the network should be shared with the host" // {
          default = true;
        };
        unshare = {
          user = mkEnableOption "If the user should be unshared with the host" // {
            default = true;
          };
          pid = mkEnableOption "If the pid should be unshared with the host" // {
            default = true;
          };
          uts = mkEnableOption "If the uts should be unshared with the host" // {
            default = true;
          };
          ipc = mkEnableOption "If the ipc should be unshared with the host" // {
            default = true;
          };
          cgroup = mkEnableOption "If the cgroup should be unshared with the host" // {
            default = true;
          };
          net = mkEnableOption "If the network should be unshared with the host" // {
            default = true;
          };
        };
        dieWithParent = mkEnableOption "If the instance should die with it's parent" // {
          default = true;
        };
        chdir = mkOption {
          description = ''
            Optional directory to change to with `--chdir`
          '';
          type = types.nullOr types.str;
          default = null;
        };
        flags = mkOption {
          description = ''
            The list of flags to pass to the `bwrap` executable
            to configure how bubblewrap gets started.

            Warning: by default this is what the other config
            options become. Settings this may have unintended consequences.
          '';
          type = types.listOf types.str;
          default = [ ];
        };
        appendFlags = mkOption {
          description = ''
            Flags to append at the end of the bubblewrap invocation.
          '';
          type = types.listOf types.str;
          default = [ ];
        };
        prependFlags = mkOption {
          description = ''
            Flags to prepend at the start of the bubblewrap invocation.
          '';
          type = types.listOf types.str;
          default = [ ];
        };
      };
    };
    default = { };
  };

  config = {
    assertions = [
      {
        assertion = lib.all (x: lib.toUpper x == x) (lib.attrNames cfg.environment);
        message = "settings.bubblewrap.environment must have all uppercase keys.";
      }
    ];

    settings.bubblewrap.flags =
      cfg.prependFlags
      ++ lib.concatMap (
        { name, value }:
        [
          "--setenv"
          name
          value
        ]
      ) (lib.attrsToList cfg.environment)
      ++ lib.concatMap (tmpfs: [
        "--tmpfs"
        tmpfs
      ]) (cfg.tmpfs ++ cfg.extraTmpfs)
      ++ lib.concatMap (
        { src, dest }:
        [
          "--ro-bind"
          src
          dest
        ]
      ) cfg.roBinds
      ++ lib.optionals cfg.bind.dev [
        "--dev"
        "/dev"
      ]
      ++ lib.optionals cfg.bind.proc [
        "--proc"
        "/proc"
      ]
      ++ lib.optionals (cfg.chdir != null) [
        "--chdir"
        cfg.chdir
      ]
      ++ lib.optional cfg.share.net "--share-net"
      ++ lib.optional cfg.unshare.user "--unshare-user"
      ++ lib.optional cfg.unshare.pid "--unshare-pid"
      ++ lib.optional cfg.unshare.uts "--unshare-uts"
      ++ lib.optional cfg.unshare.ipc "--unshare-ipc"
      ++ lib.optional cfg.unshare.cgroup "--unshare-cgroup"
      ++ cfg.appendFlags;
  };
}
