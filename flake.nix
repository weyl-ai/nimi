{
  description = "Container PID 1 and process runner for Nix Modular Services";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs =
    { nixpkgs, ... }:
    let
      inherit (nixpkgs) lib;
      eachSystem =
        fn:
        lib.genAttrs lib.systems.flakeExposed (
          system:
          let
            pkgs = nixpkgs.legacyPackages.${system};
          in
          fn { inherit pkgs system; }
        );
    in
    {
      packages = eachSystem ({ pkgs, ... }: import ./default.nix { inherit pkgs; });
      checks = eachSystem ({ pkgs, ... }: import ./nix/checks.nix { inherit pkgs; });

      shell = eachSystem (
        { pkgs, ... }:
        {
          default = import ./shell.nix { inherit pkgs; };
        }
      );
      formatter = eachSystem ({ pkgs, ... }: pkgs.callPackage ./nix/formatter.nix { });
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
