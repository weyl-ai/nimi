# Config Data Files

`configData` lets modular service modules supply config files to a service
instance. `Nimi` treats the entries in the generated JSON as the final, resolved
files to expose.

At runtime, for each service:

- `Nimi` serializes the service's `configData` entries, hashes them, and creates a
  temp directory (usually under `/tmp`) named `nimi-config-<sha256>`.
- Each `configData.<name>.source` is symlinked into that directory at the
  relative `configData.<name>.path` location.
- The service is started with `XDG_CONFIG_HOME` set to the temp directory, so it
  can read config files at `$XDG_CONFIG_HOME/<path>`.

`Nimi` does not render `configData.<name>.text` itself; the Nix evaluation/build
step generates the `source` files and the JSON points at them. Hence, updating the content
requires rebuilding the config and restarting `Nimi`.
