{
  pkgs ? import <nixpkgs> { },
  nix2container ? import <nix2container> { },
}:

rec {
  nimi = pkgs.callPackage ./nix/package.nix { inherit nix2container; };
  default = nimi;

  docs = pkgs.callPackage ./nix/docs.nix { };
}
