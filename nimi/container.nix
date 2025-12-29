{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.settings.container = mkOption {
    description = ''
      Configures nimi container generation

      Mostly mappings to `nix2container` args
    '';
    type = types.submodule {
      options = {
        name = mkOption {
          description = ''
            The name of the generated image
          '';
          type = types.str;
        };
        tag = mkOption {
          description = ''
            The tag for the generated image to use
          '';
          type = types.nullOr types.tag;
        };
        copyToRoot = mkOption {
          description = ''
            A derivation (or list of derivations) copied in the image root directory
            (store path prefixes `/nix/store/hash-path` are removed,
            in order to relocate them at the image `/`).

            `pkgs.buildEnv` can be used to build a derivation which has to
            be copied to the image root. For instance, to get bash and
            coreutils in the image `/bin`:
          '';
          type = types.either types.pathInStore (types.listOf types.pathInStore);
        };
        fromImage = mkOption {
          description = ''
            An image that is used as base image of this image;

            Use `nix2container.pullImage` or `nix2container.pullImageFromManifest` to supply this.
          '';
          type = types.pathInStore;
        };
        maxLayers = mkOption {
          description = ''
            The maximum number of layers to create.

            This is based on the store path "popularity" as described in [this blog post](https://grahamc.com/blog/nix-and-layered-docker-images/).

            Note this is applied on the image layers and not on layers added with the `buildImage.layers` attribute.
          '';
          type = types.ints.positive;
        };
        perms = mkOption {
          description = ''
            A list of file permisssions which are set when the tar layer is created: these permissions are not written to the Nix store.
          '';
          type = types.listOf types.submodule {
            path = mkOption {
              description = ''
                The store path to search for files in
              '';
              type = types.pathInStore;
            };
            regex = mkOption {
              description = ''
                All files matching this regex inside of `path` are selected
              '';
              type = types.str;
            };
            mode = mkOption {
              description = ''
                Actual mode to apply
              '';
              type = types.str;
            };
          };
        };
        initializeNixDatabase = mkOption {
          description = ''
            To initialize the Nix database with all store paths added into the image.

            Note this is only useful to run nix commands from the image,
            for instance to build an image used by a CI to run Nix builds.
          '';
          type = types.bool;
        };
        layers = mkOption {
          description = ''
            A list of layers built with the `nix2container.buildLayer` function.

            If a store path in deps or contents belongs to one of these layers, this store path is skipped.

            This is pretty useful to isolate store paths that are often updated from more stable store paths,
            to speed up build and push time.
          '';
          type = types.pathInStore;
        };
      };
    };
    default = { };
  };
}
