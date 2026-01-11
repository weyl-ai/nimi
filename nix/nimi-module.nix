{ 
  pkgs ? import <nixpkgs> { },
}:
let
  inherit (pkgs) lib;
  inherit (lib) mkOption types;

  servicesModule =
    lib.modules.importApply "${pkgs.path}/nixos/modules/system/service/portable/service.nix"
      {
        inherit pkgs;
      };
in
{
  _class = "nimi";

  options.services = mkOption {
    description = ''
      Services to run inside the nimi runtime.

      Each attribute defines a named modular service: a reusable, composable
      module that you can import, extend, and tailor for each instance. This
      gives you clear service boundaries, easy reuse across projects, and
      a consistent way to describe how each process should run.

      The `services` option is an `lazyAttrsOf` submodule: the attribute name is
      the service name, and the module content defines its behavior. You
      typically provide a service by importing a module from a package and
      then overriding or extending its options.

      For the full upstream explanation and portability model, see the
      [NixOS manual section on Modular Services](https://nixos.org/manual/nixos/unstable/#modular-services).
    '';
    example = lib.literalExpression ''
      {
        services."ghostunnel-plain-old" = {
          imports = [ pkgs.ghostunnel.services.default ];
          ghostunnel = {
            listen = "0.0.0.0:443";
            cert = "/root/service-cert.pem";
            key = "/root/service-key.pem";
            disableAuthentication = true;
            target = "backend:80";
            unsafeTarget = true;
          };
        };
        services."ghostunnel-client-cert" = {
          imports = [ pkgs.ghostunnel.services.default ];
          ghostunnel = {
            listen = "0.0.0.0:1443";
            cert = "/root/service-cert.pem";
            key = "/root/service-key.pem";
            cacert = "/root/ca.pem";
            target = "backend:80";
            allowCN = [ "client" ];
            unsafeTarget = true;
          };
        };
      }
    '';
    type = types.lazyAttrsOf (
      types.submoduleWith {
        class = "service";
        modules = [
          servicesModule
        ];
      }
    );
    default = { };
  };

  imports = [
    # (import-tree ../nimi)
  ];
}
