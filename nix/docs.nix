{
  lib,
  nixosOptionsDoc,
  runCommandLocal,
  pandoc,
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
runCommandLocal "options-doc-html" { } ''
  mkdir -p $out
  ${pandoc}/bin/pandoc \
    -f markdown \
    -t html \
    -s \
    --metadata title="Module Options" \
    -o $out/index.html \
    ${moduleOptsDoc.optionsCommonMark}
''
