{
  writeShellApplication,
  treefmt,
  lib,
  writers,
  deadnix,
  mdformat,
  nixfmt,
  rustfmt,
  shellcheck,
  shfmt,
  statix,
  toml-sort,
}:
let
  statix-fix = writeShellApplication {
    name = "statix-fix";
    text = ''
      for file in "$@"; do
        ${lib.getExe statix} fix "$file"
      done
    '';
  };

  treefmtToml = writers.writeTOML "treefmt.toml" {
    formatter = {
      deadnix = {
        command = lib.getExe deadnix;
        excludes = [ ];
        includes = [ "*.nix" ];
        options = [ "--edit" ];
      };

      mdformat = {
        command = lib.getExe mdformat;
        excludes = [ ];
        includes = [ "*.md" ];
        options = [ ];
      };

      nixfmt = {
        command = lib.getExe nixfmt;
        excludes = [ ];
        includes = [ "*.nix" ];
        options = [ ];
      };

      rustfmt = {
        command = lib.getExe rustfmt;
        excludes = [ ];
        includes = [ "*.rs" ];
        options = [
          "--config"
          "skip_children=true"
          "--edition"
          "2024"
        ];
      };

      shellcheck = {
        command = lib.getExe shellcheck;
        excludes = [ ];
        includes = [
          "*.sh"
          "*.bash"
        ];
        options = [ ];
      };

      shfmt = {
        command = lib.getExe shfmt;
        excludes = [ ];
        includes = [
          "*.sh"
          "*.bash"
          "*.envrc"
          "*.envrc.*"
        ];
        options = [
          "-w"
          "-i"
          "2"
          "-s"
        ];
      };

      statix = {
        command = lib.getExe statix-fix;
        excludes = [ ];
        includes = [ "*.nix" ];
        options = [ ];
      };

      toml-sort = {
        command = lib.getExe toml-sort;
        excludes = [ ];
        includes = [ "*.toml" ];
        options = [ "-i" ];
      };
    };
  };
in
treefmt.withConfig {
  name = "nimi-formatter";
  configFile = treefmtToml;
}
