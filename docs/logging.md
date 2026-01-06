# Logging

`Nimi` streams service logs to `stdout`/`stderr` and can also write per-service log
files when `settings.logging.enable` is set.

# File layout

When logging is enabled, `Nimi` creates a run-specific directory under
`settings.logging.logsDir` and writes one file per service:

- `logs-{n}/service-a.txt`
- `logs-{n}/service-b.txt`

> Where `n` is the successive iteration ran using the same logging directory

Each file receives line-oriented output from the service. Both `stdout` and
`stderr` are appended to the same file, so the contents reflect the combined
stream.

# Configuration

```nix
settings.logging = {
  enable = true;
  logsDir = "my_logs";
};
```

# Notes

- Log files are created at runtime; they do not exist in the Nix store.
- Disabling logging still streams logs to stdout/stderr, but no files are
  created.
