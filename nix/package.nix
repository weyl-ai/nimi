{
  rustPlatform,
  lib,
  clippy,
  callPackage,
  nix2container ? null,
  ...
}:
let
  cargoToml = fromTOML (builtins.readFile ../Cargo.toml);
in
rustPlatform.buildRustPackage (finalAttrs: {
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
    lockFile = ../Cargo.lock;
    outputHashes = {
      "mprocs-0.8.3" = "sha256-VtpKmbwsgwTMx5/GmWGz4j0IqelhX/xQyBhvp0rNHpk=";
    };
  };

  nativeBuildInputs = [ clippy ];

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

  passthru = callPackage ./lib.nix {
    inherit nix2container;
    nimi = finalAttrs.finalPackage;
  };
})
