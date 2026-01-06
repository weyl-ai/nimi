# Command Line Interface

The `Nimi` CLI is the runtime entry-point for a generated modular services config. It validates the config, runs startup hooks, launches services, and streams their logs until shutdown.

# Intended use

`Nimi` is meant to be the final step after evaluating a modular services configuration with `nimi.evalServicesConfig`. It is lightweight enough for containers, but still gives you consistent startup, restart, and shutdown behavior.

# Basic flow

1. Generate a JSON config using `nimi.evalServicesConfig`.
1. Run `nimi --config ./my-config.json validate` to check it.
1. Run `nimi --config ./my-config.json run` to launch services.

# Commands

- `validate`: read and deserialize the config to ensure it is well-formed.
- `run`: start the process manager and run all configured services.

# Flags

- `--config`, `-c`: path to the generated JSON configuration file.

# Runtime behavior

- Optional startup binary runs once before services start.
- Each service runs with a clean environment and its configured `argv`.
- Service logs stream to stdout/stderr with the service name as the log target.
- Restart behavior follows `settings.restart` (`never`, `up-to-count`, `always`).
- `Ctrl-C` triggers a graceful shutdown and waits for services to exit.

# Example

```bash
nimi --config ./result/nimi-config.json validate
nimi --config ./result/nimi-config.json run
```
