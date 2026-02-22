{
  pkgs ? import <nixpkgs> { },
  nix2container ? null,
}:

rec {
  nimi = pkgs.callPackage ./nix/package.nix { inherit nix2container; };
  default = nimi;

  # Static build for microVMs and minimal environments
  nimi-static = pkgs.pkgsStatic.callPackage ./nix/package.nix { nix2container = null; };

  docs = pkgs.callPackage ./nix/docs.nix { };
}
