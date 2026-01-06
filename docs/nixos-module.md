# `NixOS` Module

The `NixOS` module output (`nimi.nixosModules.default`) wires `Nimi` into a `NixOS`
configuration. It takes named service definitions and turns them into system
packages and `systemd` units, so you can run the same modular service config on
full `NixOS`.

## What it provides

For each `nimi.<name>` entry, the module generates:

- `environment.systemPackages`: the `Nimi` runtime binary built from the services module.
- `systemd.services.<name>`: a system service that runs the generated binary.

## Minimal example

```nix
{
  imports = [
    inputs.nimi.nixosModules.default
  ];

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
}
```

## Notes

- Each `nimi.<name>` becomes a `systemd` unit named `<name>.service`.
- The service is configured with a basic restart policy; override in `systemd.services` if needed.
