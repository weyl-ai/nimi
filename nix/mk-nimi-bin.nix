{
  flake-parts-lib,
  lib,
  ...
}:
let
  inherit (flake-parts-lib) mkPerSystemOption;
  inherit (lib) mkOption types;

  failedToCreateNimiWrapperError = "while evaluating nimi wrapper script:";
in
{
  options.perSystem = mkPerSystemOption {
    options.mkNimiBin = mkOption {
      description = ''
        Function for generating a configured Nimi instance
      '';
      type = types.functionTo types.package;
    };
  };

  config.perSystem =
    {
      self',
      pkgs,
      config,
      ...
    }:
    {
      mkNimiBin =
        module:
        let
          evaluatedConfig = config.evalNimiModule module;
          cfgJson = config.toNimiJson evaluatedConfig;
        in
        builtins.addErrorContext failedToCreateNimiWrapperError (
          pkgs.writeShellApplication {
            name = evaluatedConfig.settings.binName;
            runtimeInputs = [ self'.packages.nimi ];
            text = ''
              exec nimi --config "${cfgJson}" run "$@"
            '';
            inherit (evaluatedConfig) passthru meta;
          }
        );
    };

}
