{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  _class = "nimi";

  options.settings.binName = mkOption {
    description = ''
      Name of the binary to generate with your nimi wrapper.

      Changes the name of the default generated binary name
      from "nimi" to whatever you select.
    '';
    example = lib.literalExpression ''
      {
        settings.binName = "my-awesome-service-runner";
      }
    '';
    type = types.str;
    default = "nimi";
  };
}
