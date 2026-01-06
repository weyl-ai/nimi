# Flake Module

The flake module output (`nimi.flakeModule`) wires `Nimi` into a `flake-parts` setup.
It takes named service definitions and turns them into runnable `Nimi` binaries and
container images, so you can build local runners, CI checks, and deployable
artifacts from one source of truth.

## What it provides

For each `perSystem.nimi.<name>` entry, the module generates:

- `packages.<name>-service`: a `Nimi` runtime binary built from the services module.
- `packages.<name>-container`: a container image bundling that runtime.
- `checks.<name>-service` and `checks.<name>-container`: the same outputs, wired into CI.

## Minimal example

```nix
{
  perSystem = { pkgs, ... }: {
    nimi."web" = {
      services."my-app" = {
        process.argv = [
          (lib.getExe pkgs.my-app)
          "--port"
          "8080"
        ];
      };
      settings.restart.mode = "up-to-count";
      settings.restart.time = 2000;
    };
  };
}
```

Build or run the outputs:

```bash
nix build .#web-service
nix build .#web-container
```

## Notes

- The module is designed for `flake-parts` and expects `perSystem.nimi` entries.
- Outputs are generated per system, so each target platform gets its own runner.
