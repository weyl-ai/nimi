# Sandbox

`Nimi` provides a lightweight sandbox runner via `mkBwrap`. It uses
[bubblewrap](https://github.com/containers/bubblewrap) to run your services in
an isolated environment that mimics a container, without requiring container
runtimes like Docker or Podman.

## What it provides

- **Isolated filesystem**: A tmpfs-based root with your rootfs directories bound read-only.
- **Container-like layout**: Uses `settings.container.copyToRoot` to build the root filesystem.
- **Environment variables**: Applies `settings.container.imageConfig.Env`.
- **Working directory**: Applies `settings.container.imageConfig.WorkingDir`.
- **Volumes**: Mounts `settings.container.imageConfig.Volumes` as writable tmpfs.
- **Writable directories**: `/tmp`, `/run`, and `/var` are tmpfs mounts for runtime writes.
- **Nix store access**: `/nix/store` is bind-mounted read-only so binaries can access their dependencies.

## Minimal example

```nix
pkgs.nimi.mkBwrap {
  services."my-app" = {
    process.argv = [ (lib.getExe pkgs.my-app) ];
  };
  settings.container = {
    copyToRoot = [
      (pkgs.buildEnv {
        name = "root";
        paths = [ pkgs.coreutils pkgs.bash ];
        pathsToLink = [ "/bin" ];
      })
    ];
    imageConfig = {
      Env = [ "MY_VAR=value" ];
      WorkingDir = "/app";
      Volumes = { "/data" = { }; };
    };
  };
};
```

Run the sandbox:

```bash
nix run .#my-sandbox
```

## How it works

1. **Build time**: `copyToRoot` derivations are merged into a single rootfs using `symlinkJoin`.
1. **Execution**: `bwrap` runs the `Nimi` binary inside an isolated namespace with:
   - A tmpfs as the root filesystem
   - Directories from `copyToRoot` bound read-only
   - `/nix/store` bind-mounted read-only
   - `/tmp`, `/run`, `/var` as writable tmpfs
   - Environment variables and working directory from `imageConfig`
   - Volumes as tmpfs mounts

## Differences from containers

| Feature | `mkBwrap` | `mkContainerImage` |
|---------|-----------|-------------------|
| Runtime dependencies | `bubblewrap` only | Container runtime (Docker, Podman) |
| Image format | None (uses Nix store directly) | OCI image |
| Startup time | Fast (no image loading) | Depends on runtime |
| Portability | Linux only | Any OCI-compatible runtime |
| Base images | Not supported | Supported via `fromImage` |
| Writable root | No (tmpfs dirs only) | Yes |

## Notes

- The sandbox requires Linux with user namespaces enabled.
- The rootfs is read-only; writes go to tmpfs directories (`/tmp`, `/run`, `/var`, and configured volumes).
- Signal handling (Ctrl+C) is supported.
- The `entrypoint` is always the generated `Nimi` runner from `mkNimiBin`.
