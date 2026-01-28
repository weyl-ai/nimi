{ lib, config, ... }:
let
  inherit (lib) mkOption mkEnableOption types;

  cfg = config.settings.bubblewrap;

  roBindType = types.submodule {
    options.src = mkOption {
      description = "Host path to bind into the sandbox.";
      type = types.str;
      example = "/etc/resolv.conf";
    };
    options.dest = mkOption {
      description = "Path inside the sandbox where `src` appears.";
      type = types.str;
      example = "/etc/resolv.conf";
    };
  };
in
{
  _class = "nimi";

  options.settings.bubblewrap = mkOption {
    description = ''
      Sandbox configuration for running nimi inside bubblewrap.

      Use this to isolate the nimi process manager and its services from the
      host system. Bubblewrap provides lightweight containerization through
      Linux namespaces without requiring root privileges or a container runtime.

      The defaults provide a minimal sandbox that can access the Nix store and
      network while isolating the process namespace, filesystem writes, and
      other system resources. Adjust these settings based on what your services
      actually need.

      Note that these options only take effect when using `nimi.mkBwrap` to
      build your sandboxed binary.
    '';
    example = lib.literalExpression ''
      {
        environment.APP_ENV = "production";
        chdir = "/app";
        roBinds = [
          { src = "/nix/store"; dest = "/nix/store"; }
          { src = "/etc/ssl"; dest = "/etc/ssl"; }
        ];
        extraTmpfs = [ "/app/cache" ];
      }
    '';
    type = types.submodule {
      options = {
        environment = mkOption {
          description = ''
            Environment variables to set inside the sandbox.

            These are passed to bubblewrap via `--setenv` and are available to
            the nimi process manager and all services it spawns. Variable names
            must be uppercase.
          '';
          type = types.lazyAttrsOf types.str;
          default = { };
          example = lib.literalExpression ''
            {
              APP_ENV = "production";
              LOG_LEVEL = "info";
            }
          '';
        };
        roBinds = mkOption {
          description = ''
            Read-only bind mounts from the host into the sandbox.

            Each entry maps a host path (`src`) to a path inside the sandbox
            (`dest`). The sandbox can read these paths but not modify them.

            The default includes `/nix/store` (required for Nix binaries) and
            `/sys` (for system information). Override this list carefully;
            omitting `/nix/store` will break most Nix-built programs.

            For paths that may not exist on all systems, use `tryRoBinds`
            instead.
          '';
          type = types.listOf roBindType;
          default = [
            {
              src = "/nix/store";
              dest = "/nix/store";
            }
            {
              src = "/sys";
              dest = "/sys";
            }
          ];
          example = lib.literalExpression ''
            [
              { src = "/nix/store"; dest = "/nix/store"; }
              { src = "/etc/ssl"; dest = "/etc/ssl"; }
              { src = "/run/secrets"; dest = "/secrets"; }
            ]
          '';
        };
        tryRoBinds = mkOption {
          description = ''
            Read-only bind mounts that are skipped if the source does not exist.

            Like `roBinds`, but uses `--ro-bind-try` which silently skips the
            mount if the host path does not exist. Use this for paths that may
            not be present on all systems.

            The default includes `/etc/resolv.conf` for DNS resolution, which
            may not exist on systems using systemd-resolved or other DNS
            configurations.
          '';
          type = types.listOf roBindType;
          default = [
            {
              src = "/etc/resolv.conf";
              dest = "/etc/resolv.conf";
            }
          ];
          example = lib.literalExpression ''
            [
              { src = "/etc/resolv.conf"; dest = "/etc/resolv.conf"; }
              { src = "/etc/hosts"; dest = "/etc/hosts"; }
            ]
          '';
        };
        tmpfs = mkOption {
          description = ''
            Paths to mount as temporary filesystems inside the sandbox.

            These mounts are writable but ephemeral; contents are lost when the
            sandbox exits. They also hide any host content at the same path.

            The default list creates writable areas for common system paths
            while keeping the sandbox isolated. The `/nix` tmpfs is mounted
            first, then `/nix/store` is bind-mounted on top, allowing writes
            elsewhere under `/nix` (like `/nix/var`) without touching the
            real store.
          '';
          type = types.listOf types.str;
          default = [
            "/nix"
            "/tmp"
            "/run"
            "/var"
            "/etc"
          ];
          example = lib.literalExpression ''
            [ "/tmp" "/run" ]
          '';
        };
        extraTmpfs = mkOption {
          description = ''
            Additional tmpfs mounts appended to the default list.

            Use this to add writable scratch directories without replacing
            the standard set. For complete control, override `tmpfs` directly.
          '';
          type = types.listOf types.str;
          default = [ ];
          example = lib.literalExpression ''
            [ "/app/cache" "/app/tmp" ]
          '';
        };
        bind = {
          dev = mkEnableOption "bind /dev into the sandbox" // {
            default = true;
          };
          proc = mkEnableOption "bind /proc into the sandbox" // {
            default = true;
          };
        };
        unshare = {
          user = mkEnableOption "create a new user namespace" // {
            default = true;
          };
          pid = mkEnableOption "create a new PID namespace" // {
            default = true;
          };
          uts = mkEnableOption "create a new UTS (hostname) namespace" // {
            default = true;
          };
          ipc = mkEnableOption "create a new IPC namespace" // {
            default = true;
          };
          cgroup = mkEnableOption "create a new cgroup namespace" // {
            default = true;
          };
        };
        dieWithParent = mkEnableOption "terminate sandbox when parent process exits" // {
          default = true;
        };
        chdir = mkOption {
          description = ''
            Working directory to change to after entering the sandbox.

            Set this to control where services start. When `null`, bubblewrap
            does not change directory and the process inherits the caller's
            working directory (usually `/`).
          '';
          type = types.nullOr types.str;
          default = null;
          example = lib.literalExpression ''"/app"'';
        };
        flags = mkOption {
          description = ''
            Final list of flags passed to the `bwrap` executable.

            This is computed automatically from the other options in this
            module. You can read it to inspect the generated command line, but
            setting it directly replaces the generated flags entirely and may
            break the sandbox. Prefer `prependFlags` or `appendFlags` to inject
            custom arguments.
          '';
          type = types.listOf types.str;
          default = [ ];
        };
        appendFlags = mkOption {
          description = ''
            Extra flags appended after the generated bubblewrap arguments.

            Use this for one-off bwrap options not covered by the module.
            These appear at the end of the command line, just before `--`.
          '';
          type = types.listOf types.str;
          default = [ ];
          example = lib.literalExpression ''
            [ "--cap-add" "CAP_NET_BIND_SERVICE" ]
          '';
        };
        prependFlags = mkOption {
          description = ''
            Extra flags inserted before the generated bubblewrap arguments.

            Use this when argument order matters, for example to set options
            that must appear early in the bwrap invocation.
          '';
          type = types.listOf types.str;
          default = [ ];
          example = lib.literalExpression ''
            [ "--clearenv" ]
          '';
        };
      };
    };
    default = { };
  };

  config = {
    assertions = [
      {
        assertion = lib.all (x: lib.match "[A-Za-z_][A-Za-z0-9_]*" x != null) (
          lib.attrNames cfg.environment
        );
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
      ++ lib.concatMap (
        { src, dest }:
        [
          "--ro-bind-try"
          src
          dest
        ]
      ) cfg.tryRoBinds
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
      ++ lib.optional cfg.unshare.user "--unshare-user"
      ++ lib.optional cfg.unshare.pid "--unshare-pid"
      ++ lib.optional cfg.unshare.uts "--unshare-uts"
      ++ lib.optional cfg.unshare.ipc "--unshare-ipc"
      ++ lib.optional cfg.unshare.cgroup "--unshare-cgroup"
      ++ lib.optional cfg.dieWithParent "--die-with-parent"
      ++ cfg.appendFlags;
  };
}
