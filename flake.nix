{
  description = "Container PID 1 and process runner for Nix Modular Services";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.nix2container = {
    url = "github:nlewo/nix2container";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    { nixpkgs, nix2container, ... }:
    let
      inherit (nixpkgs) lib;

      overlay =
        final: _prev:
        let
          inherit (final.stdenv.hostPlatform) system;
        in
        {
          nimi = final.callPackage ./nix/package.nix {
            inherit (nix2container.packages.${system}) nix2container;
          };
          inherit nix2container;
        };

      eachSystem =
        fn:
        lib.genAttrs lib.systems.flakeExposed (
          system:
          (fn rec {
            inherit system;
            pkgs = nixpkgs.legacyPackages.${system}.appendOverlays [
              overlay
            ];
            inherit (pkgs) callPackage;
          })
        );
    in
    {
      packages = eachSystem (
        { pkgs, system, ... }:
        import ./default.nix {
          inherit pkgs;
          inherit (nix2container.packages.${system}) nix2container;
        }
      );
      devShells = eachSystem (
        { pkgs, ... }:
        {
          default = import ./shell.nix { inherit pkgs; };
        }
      );

      checks = eachSystem (
        { callPackage, ... }:
        let
          checksFromDir =
            directory:
            lib.packagesFromDirectoryRecursive {
              inherit callPackage directory;
            };
        in
        (checksFromDir ./examples) // (checksFromDir ./nix/checks)
      );

      formatter = eachSystem ({ callPackage, ... }: callPackage ./nix/formatter.nix { });

      overlays.default = overlay;

      nixosModules.default = lib.modules.importApply ./nix/modules/nixos.nix {
        inherit nix2container;
      };
      homeModules.default = lib.modules.importApply ./nix/modules/home-manager.nix {
        inherit nix2container;
      };
      flakeModules.default = lib.modules.importApply ./nix/modules/flake-parts.nix {
        inherit nix2container;
      };
      nimiModules.default = import ./nix/modules/nimi.nix;
    };

  nixConfig = {
    extra-substituters = [
      "https://weyl-ai.cachix.org"
    ];
    extra-trusted-public-keys = [
      "weyl-ai.cachix.org-1:cR0SpSAPw7wejZ21ep4SLojE77gp5F2os260eEWqTTw="
    ];
  };
}
