{
  perSystem =
    { pkgs, self', ... }:
    {
      checks.container = self'.packages.nimi.mkContainerImage {
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
        settings.restart.mode = "up-to-count";
      };
    };
}
