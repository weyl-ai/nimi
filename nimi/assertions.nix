{
  lib,
  config,
  options,
  ...
}:
let
  inherit (lib) mkOption types;

  assertionType = types.submodule {
    options = {
      assertion = mkOption {
        type = types.bool;
        description = ''
          Assertion to evaluate and check.
        '';
      };
      message = mkOption {
        type = types.str;
        description = ''
          Message to print on assertion failure.
        '';
      };
    };
  };

  failedEvaluatingAssertionsError = "while checking nimi assertions and warnings:";
in
{
  _class = "nimi";

  options = {
    assertions = mkOption {
      type = types.listOf assertionType;
      internal = true;
      default = [ ];
      example = [
        {
          assertion = false;
          message = "you can't enable this for that reason";
        }
      ];
      description = ''
        This option allows modules to express conditions that must
        hold for the evaluation of the system configuration to
        succeed, along with associated error messages for the user.
      '';
    };

    warnings = mkOption {
      internal = true;
      default = [ ];
      type = types.listOf types.str;
      example = [ "The `foo' service is deprecated and will go away soon!" ];
      description = ''
        This option allows modules to show warnings to users during
        the evaluation of the system configuration.
      '';
    };

    "nimi assertions and warnings evaluation results" = mkOption {
      internal = true;
      default = [ ];
      type = types.bool;
      description = ''
        Placeholder module that's impossible to evaluate without running through the assertions first
      '';
    };
  };

  config."nimi assertions and warnings evaluation results" =
    let
      assertNimiConfig =
        { value, file }:
        (
          assert lib.assertMsg value.assertion ''
            Nimi assertion failed:

            > ${value.message}

            Failed assertion source (file):

            > '${file}'

          '';
          value.assertion
        );

      fileValuePairs = lib.concatMap (
        def:
        map (value: {
          inherit (def) file;
          inherit value;
        }) def.value
      ) options.assertions.definitionsWithLocations;

      assertions = builtins.all lib.id (map assertNimiConfig fileValuePairs);

      warnings = lib.pipe config.warnings [
        (map (x: lib.warn x x))
        (map lib.isString)
        (builtins.all lib.id)
      ];
    in
    builtins.addErrorContext failedEvaluatingAssertionsError assertions && warnings;
}
