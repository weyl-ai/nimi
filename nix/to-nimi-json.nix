{
  flake-parts-lib,
  lib,
  ...
}:
let
  inherit (flake-parts-lib) mkPerSystemOption;
  inherit (lib) mkOption types;

  failedConversionToJSONError = "while serializing nimi config to json:";
in
{
  options.perSystem = mkPerSystemOption {
    options.toNimiJson = mkOption {
      description = ''
        Takes an evaluated nimi config and produces a validated,
        formatted json file from it.
      '';
      type = types.functionTo types.package;
    };
  };

  config.perSystem =
    { self', pkgs, ... }:
    {
      toNimiJson =
        evaluatedConfig:
        let
          inputJSON = builtins.addErrorContext failedConversionToJSONError (builtins.toJSON evaluatedConfig);

          formattedJSON =
            pkgs.runCommandLocal "nimi-config-formatted.json"
              {
                nativeBuildInputs = [
                  pkgs.jq
                ];
              }
              ''
                jq . <<'EOF' > "$out"
                ${inputJSON}
                EOF
              '';

        in
        pkgs.runCommandLocal "nimi-config-validated.json"
          {
            nativeBuildInputs = [
              self'.packages.nimi
            ];
          }
          ''
            ln -sf "${formattedJSON}" "$out"

            nimi --config "${formattedJSON}" validate
          '';
    };

}
