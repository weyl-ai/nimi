{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  _class = "nimi";

  options.passthru = mkOption {
    description = ''
      [`passthru`](https://ryantm.github.io/nixpkgs/stdenv/stdenv/#var-stdenv-passthru) attributes to
      include in the output of generated `Nimi` packages
    '';
    example = lib.literalExpression ''
      {
        passthru = {
          doXYZ = pkgs.writeShellApplication {
            name = "xyz-doer";
            text = '''
              xyz
            ''';
          };
        };
      }
    '';
    type = types.lazyAttrsOf types.raw;
    default = { };
  };
}
