# Sandbox

`Nimi` provides a lightweight sandbox runner via `mkSandbox`. It uses
[bubblewrap](https://github.com/containers/bubblewrap) and
[fuse-overlayfs](https://github.com/containers/fuse-overlayfs) to run your
services in an isolated environment that mimics a container, without requiring
container runtimes like Docker or Podman.

## What it provides

- **Isolated filesystem**: A copy-on-write overlay where writes are discarded on exit.
- **Container-like layout**: Uses `settings.container.copyToRoot` to build the root filesystem.
- **Environment variables**: Applies `settings.container.imageConfig.Env`.
- **Working directory**: Applies `settings.container.imageConfig.WorkingDir`.
- **Volumes**: Mounts `settings.container.imageConfig.Volumes` as writable tmpfs.
- **Nix store access**: `/nix/store` is bind-mounted read-only so binaries can access their dependencies.

## Minimal example

```nix
pkgs.nimi.mkSandbox {
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
1. **Runtime**: `fuse-overlayfs` creates a copy-on-write layer over the rootfs.
1. **Execution**: `bwrap` runs the `Nimi` binary inside the isolated namespace with:
   - The overlay mounted as `/`
   - `/nix/store` bind-mounted read-only
   - Environment variables and working directory from `imageConfig`
   - Volumes as `tmpfs` mounts
1. **Cleanup**: On exit, the overlay is unmounted and temporary files are removed.

## Differences from containers

| Feature | `mkSandbox` | `mkContainerImage` |
|---------|-------------|-------------------|
| Runtime dependencies | `bubblewrap`, `fuse-overlayfs` | Container runtime (Docker, Pod-man) |
| Image format | None (uses Nix store directly) | OCI image |
| Startup time | Fast (no image loading) | Depends on runtime |
| Portability | Linux only | Any OCI-compatible runtime |
| Base images | No support | Supported via `fromImage` |

## Notes

- The sandbox requires Linux with FUSE support.
- Writes inside the sandbox are isolated and do not affect the host or Nix store.
- Signal handling (Ctrl+C) is supported and cleanly terminates the sandbox.
- The `entrypoint` is always the generated `Nimi` runner from `mkNimiBin`.
