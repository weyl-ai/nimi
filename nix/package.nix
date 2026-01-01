{ self, lib, ... }:
let
  cargoToml = fromTOML (builtins.readFile "${self}/Cargo.toml");
in
{
  perSystem =
    { pkgs, config, ... }:
    rec {
      packages.nimi = pkgs.rustPlatform.buildRustPackage {
        pname = cargoToml.package.name;
        inherit (cargoToml.package) version;

        src = lib.fileset.toSource {
          root = ../.;
          fileset = lib.fileset.unions [
            ../Cargo.lock
            ../Cargo.toml
            ../src
          ];
        };

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
          inherit (config)
            mkNimiBin
            mkContainerImage
            evalNimiModule
            toNimiJson
            ;
        };
      };

      packages.default = packages.nimi;
      checks.nimi = packages.nimi;
    };
}
