{ self, ... }:
{
  perSystem =
    { inputs', pkgs, ... }:
    {
      packages.docs =
        let
          moduleOpts = pkgs.lib.evalModules {
            modules = [ self.modules.nimi.default ];
          };

          moduleOptsDoc = pkgs.nixosOptionsDoc {
            options = moduleOpts;
          };
        in
        pkgs.runCommandLocal "nimi-docs"
          {
            nativeBuildInputs = [ inputs'.ndg.packages.default ];
          }
          ''
            mkdir -p "$out/share/nimi/docs"

            ndg html \
              --input-dir "${self}/docs" \
              --output-dir "$out/share/nimi/docs" \
              --title "Nimi Documentation" \
              --module-options ${moduleOptsDoc.optionsJSON}/share/doc/nixos/options.json \
              --jobs $NIX_BUILD_CORES \
              --generate-search \
              --highlight-code
          '';
    };
}
