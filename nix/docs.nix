{
  lib,
  nixosOptionsDoc,
  mdbook,
  stdenvNoCC,
  pkgs,
}:
let
  defaultNimiModule = lib.modules.importApply ./nimi-module.nix { inherit pkgs; };

  moduleOpts = lib.evalModules {
    modules = [ defaultNimiModule ];
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
