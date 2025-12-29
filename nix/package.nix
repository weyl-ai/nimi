{ self, lib, ... }:
let
  cargoToml = builtins.fromTOML (builtins.readFile "${self}/Cargo.toml");
in
{
  perSystem =
    { pkgs, config, ... }:
    rec {
      packages.nimi = pkgs.rustPlatform.buildRustPackage {
        pname = cargoToml.package.name;
        inherit (cargoToml.package) version;

        src = lib.sources.cleanSourceWith {
          src = self;
          filter =
            path: _type:
            let
              rel = lib.removePrefix (toString self + "/") (toString path);
            in
            rel == "Cargo.toml" || rel == "Cargo.lock" || rel == "src" || lib.hasPrefix "src/" rel;
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
