{ self, lib, ... }:
let
  cargoToml = builtins.fromTOML (builtins.readFile "${self}/Cargo.toml");
in
{
  perSystem =
    { pkgs, config, ... }:
    rec {
      packages.nimi = pkgs.rustPlatform.buildRustPackage (_finalAttrs: {
        pname = cargoToml.package.name;
        inherit (cargoToml.package) version;

        src = self;

        cargoLock = {
          lockFile = "${self}/Cargo.lock";
        };

        nativeBuildInputs = [
          pkgs.clippy
        ];

        preBuild = ''
          cargo clippy -- -D warnings
        '';

        meta = {
          description = "Tini-like PID 1 for containers and target for NixOS modular services";
          homepage = "https://github.com/weyl-ai/nimi";
          license = lib.licenses.mit;
          maintainers = [ lib.maintainers.baileylu ];
          mainProgram = "nimi";
        };

        passthru = {
          inherit (config) evalServicesConfig;
        };
      });

      packages.default = packages.nimi;
      checks.nimi = packages.nimi;
    };
}
