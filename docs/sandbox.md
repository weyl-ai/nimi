# Sandbox

`Nimi` provides a lightweight sandbox runner via `mkBwrap`. It uses
[bubblewrap](https://github.com/containers/bubblewrap) to run your services in
an isolated environment without requiring container runtimes like Docker or
Podman.

## What it provides

- **Isolated filesystem**: A tmpfs-based root with selective host paths bound read-only.
- **Environment variables**: Set via `settings.bubblewrap.environment`.
- **Working directory**: Set via `settings.bubblewrap.chdir`.
- **Namespace isolation**: Separate user, PID, UTS, IPC, and cgroup namespaces by default.
- **Writable directories**: `/tmp`, `/run`, `/var`, `/etc` are tmpfs mounts for runtime writes.
- **Nix store access**: `/nix/store` is bind-mounted read-only so binaries can access their dependencies.

## Minimal example

```nix
pkgs.nimi.mkBwrap {
  services."my-app" = {
    process.argv = [ (lib.getExe pkgs.my-app) ];
  };
  settings.bubblewrap = {
    environment.MY_VAR = "value";
    chdir = "/app";
    extraTmpfs = [ "/data" ];
  };
}
```

Run the sandbox:

```bash
nix run .#my-sandbox
```

## Extended example

```nix
pkgs.nimi.mkBwrap {
  services."web-server" = {
    process.argv = [ (lib.getExe pkgs.nginx) "-g" "daemon off;" ];
  };
  settings.bubblewrap = {
    environment = {
      APP_ENV = "production";
      LOG_LEVEL = "info";
    };
    chdir = "/srv";
    roBinds = [
      { src = "/nix/store"; dest = "/nix/store"; }
      { src = "/etc/ssl"; dest = "/etc/ssl"; }
      { src = "/run/secrets"; dest = "/secrets"; }
    ];
    extraTmpfs = [ "/var/cache/nginx" ];
  };
}
```

## How it works

1. **Build time**: The nimi binary is wrapped in a shell script that invokes `bwrap`.
1. **Execution**: `bwrap` runs the nimi binary inside an isolated namespace with:
   - Tmpfs mounts created first (providing writable areas)
   - Read-only bind mounts layered on top (e.g., `/nix/store` over `/nix`)
   - `/dev` and `/proc` bound from the host
   - Environment variables and working directory applied
   - Namespaces unshared according to configuration

## Differences from containers

| Feature | `mkBwrap` | `mkContainerImage` |
|---------|-----------|-------------------|
| Runtime dependencies | `bubblewrap` only | Container runtime (Docker, Podman) |
| Image format | None (uses Nix store directly) | OCI image |
| Startup time | Fast (no image loading) | Depends on runtime |
| Portability | Linux only | Any OCI-compatible runtime |
| Base images | Not supported | Supported via `fromImage` |
| Root filesystem | Tmpfs with bind mounts | Layered image filesystem |

## Notes

- The sandbox requires Linux with user namespaces enabled.
- Writes go to tmpfs directories; they are lost when the sandbox exits.
- Signal handling (Ctrl+C) is supported.
- The entrypoint is always the generated nimi runner from `mkNimiBin`.
- Not available on macOS (`meta.badPlatforms` includes Darwin).
