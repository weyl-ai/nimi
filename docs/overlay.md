# Overlay

`Nimi` exposes an overlay as a standalone flake output. Use it when you want to
add `nimi` to an existing `nixpkgs` instance in order to make using the `passthru` attributes easier.

## Example

```nix
{
  inputs.nimi.url = "github:weyl-ai/nimi";

  outputs = { self, nixpkgs, nimi, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ nimi.overlays.default ];
      };
    in
    {
      packages.${system}.default = pkgs.nimi;
    };
}
```
