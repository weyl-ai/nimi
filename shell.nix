{
  pkgs ? import <nixpkgs> { },
}:
let
  inherit (pkgs) lib stdenv;

  moldHook =
    pkgs.makeSetupHook
      {
        name = "mold-hook";

        propagatedBuildInputs = with pkgs; [
          mold
        ];
      }
      (
        pkgs.writeText "moldHook.sh" ''
          export RUSTFLAGS="-C link-arg=-fuse-ld=mold"
        ''
      );
in
pkgs.mkShell {
  packages = with pkgs; [
    rustc
    cargo
    rustfmt
    clippy

    podman

    (lib.optional (!stdenv.isDarwin) moldHook)
  ];
}
