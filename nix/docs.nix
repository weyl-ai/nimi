{
  lib,
  nixosOptionsDoc,
  mdbook,
  stdenvNoCC,
  pkgs,
}:
let
  moduleEval = lib.evalModules {
    modules = [
      ./modules/nimi.nix
    ];
    class = "nimi";
    specialArgs = { inherit pkgs; };
  };

  moduleOptsDoc = nixosOptionsDoc {
    inherit (moduleEval) options;
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
