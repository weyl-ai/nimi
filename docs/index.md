# `Nimi`

`Nimi` is a tiny process manager built for running NixOS modular services in containers and other minimal environments. It turns a NixOS modular services configuration into a reliable, lightweight runtime that starts services, streams logs, and applies predictable restart and startup behavior.

# Why `Nimi`

Modular services are composable Nix modules: you can import a service, override options, and instantiate it multiple times with different settings. `Nimi` is the runtime that brings those modules to life outside a full init system (i.e. `systemd`).

If you are new to modular services, the upstream explanation is the best place to start: [NixOS Modular Services Manual](https://nixos.org/manual/nixos/unstable/#modular-services).

# What's in the box

- A small PID 1 style runtime suitable for containers.
- Clean process execution with structured startup and shutdown flow.
- Configurable restart behavior for resilient services.
- One-time startup hook for quick initialization steps.
- Clear, instance-per-service configuration using modular services.

# Usage

1. Define services using modular service modules.
1. Evaluate the config with `nimi.mkNimiBin` to produce JSON.
1. Run `Nimi` with the generated config to launch and supervise services.

# Quick-start

Minimal Nix configuration:

```nix
packages.${system}.myNimiWrapper = pkgs.nimi.mkNimiBin {
  services."my-service" = {
    imports = [ pkgs.some-application.services.default ];
    someApplication = {
      listen = "0.0.0.0:8080";
      dataDir = "/var/lib/my-service";
    };
  };
  settings.restart.mode = "up-to-count";
  settings.restart.time = 2000;
}
```

Run the generated config:

```bash
nix run .#myNimiWrapper
```

# Configuration highlights

- `services`: declare named service instances by importing modular service
  modules and overriding options per instance.
- `settings.restart`: choose `never`, `up-to-count`, or `always`, and tune delay
  and retry count.
- `settings.startup`: optionally run one binary before services start.
- `settings.logging`: write per-service log files; see `docs/logging.md`.
- `configData`: define per-service config files; see `docs/config-data.md`.

# Next steps

- Explore service definitions and compose them per environment.
- Use restart policies to match reliability needs.
- Add a startup hook for migrations, warm-ups, or one-time init tasks.
- Create containers with `docs/container.md`.
- Integrate with Nix tooling: `docs/flake-module.md`, `docs/nixos-module.md`, and `docs/home-module.md`.
