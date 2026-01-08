{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  _class = "nimi";

  options.meta = mkOption {
    description = ''
      [`meta`](https://ryantm.github.io/nixpkgs/stdenv/meta/) attributes to
      include in the output of generated `Nimi` packages
    '';
    example = lib.literalExpression ''
      {
        meta = {
          description = "My cool nimi package";
        };
      }
    '';
    type = types.lazyAttrsOf types.raw;
    default = { };
  };
}
