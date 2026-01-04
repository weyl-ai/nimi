# Containers

`Nimi` ships with a built-in container generator wired through `nimi.mkContainerImage`.
It evaluates the same modular services config as `mkNimiBin`, then builds an OCI
image via `nix2container.buildImage` with the `Nimi` runner set as the `entrypoint`.

# Minimal example

```nix
nimi.mkContainerImage {
  services."my-app" = {
    imports = [ pkgs.some-application.services.default ];
    someApplication.listen = "0.0.0.0:8080";
  };
  settings.restart.mode = "up-to-count";
};
```

Build the image:

```bash
nix build .#my-container
```

# Image settings

Use `settings.container` to control the image build. These options map directly
to `nix2container.buildImage`, so you can pass things like a base image or extra
files.

```nix
settings.container = {
  name = "my-app";
  tag = "v1";
  fromImage = inputs.nix2container.packages.${system}.nix2container.pullImage {
    imageName = "alpine";
    imageDigest = "sha256:...";
    finalImageName = "alpine";
    finalImageTag = "3.20";
  };
  copyToRoot = [
    (pkgs.buildEnv {
      name = "runtime-bins";
      paths = [ pkgs.coreutils pkgs.bash ];
      pathsToLink = [ "/bin" ];
    })
  ];
};
```

# Notes

- The `entrypoint` is always the generated `Nimi` runner from `mkNimiBin`.
- `settings.container` only has an effect when building with `mkContainerImage`.
