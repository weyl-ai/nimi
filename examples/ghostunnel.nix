# This package seems to be used as the testbed for development of Modular Services in `nixpkgs`

{
  perSystem =
    { pkgs, self', ... }:
    {
      checks.ghostunnel = self'.packages.nimi.evalServicesConfig {
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
      };
    };
}
