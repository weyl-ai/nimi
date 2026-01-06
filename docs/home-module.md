# Home Manager Module

The Home Manager module output (`nimi.homeModules.default`) wires `Nimi` into a
Home Manager configuration. It takes named service definitions and turns them
into user packages and `systemd` user units, so you can run the same modular
service config as per-user services.

## What it provides

For each `nimi.<name>` entry, the module generates:

- `home.packages`: the `Nimi` runtime binary built from the services module.
- `systemd.user.services.<name>`: a user service that runs the generated binary.

## Minimal example

```nix
{
  imports = [
    inputs.nimi.homeModules.default
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

- Each `nimi.<name>` becomes a `systemd --user` unit named `<name>.service`.
- User services may require `loginctl enable-linger` if you need them running without an active session.
