{
  lib,
  nixosOptionsDoc,
  mdbook,
  stdenvNoCC,
  pkgs,
}:
let
  moduleOpts = lib.evalModules {
    modules = [
      ./modules/nimi.nix
    ];
    specialArgs = { inherit pkgs; };
  };

  moduleOptsDoc = nixosOptionsDoc {
    options = moduleOpts;
  };
in
stdenvNoCC.mkDerivation {
  name = "options-doc-html";
  src = ../.;

  nativeBuildInputs = [
    mdbook
  ];

  dontBuild = true;
  installPhase = ''
    mkdir -p "$out/share/nimi/docs"

    ln -sf "${moduleOptsDoc.optionsCommonMark}" docs/options.md

    mdbook build --dest-dir "$out/share/nimi/docs"
  '';
}
