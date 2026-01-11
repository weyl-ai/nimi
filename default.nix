{
  pkgs ? import <nixpkgs> { },
  nix2container ? null,
}:

rec {
  nimi = pkgs.callPackage ./nix/package.nix { inherit nix2container; };
  default = nimi;

  docs = pkgs.callPackage ./nix/docs.nix { };
}
