{ self, lib, config, ... }:
{
  # Do not import nix-index-database's module: importing it enables
  # programs.nix-index with the full database on every host, including
  # hosts where comma is disabled.
  # WORKAROUND: https://github.com/nix-community/nix-index-database/blob/main/nixos-module.nix

  options.modules.shell.comma.enable =
    lib.mkEnableOption "comma with the small nix-index database";

  config = lib.mkIf config.modules.shell.comma.enable {
    user.packages = [
      self.inputs.nix-index-database.packages.comma-with-db
    ];

    programs.nix-index = {
      enable = true;
      package = self.inputs.nix-index-database.packages.nix-index-with-small-db;
    };

    # Determinate's registry points nixpkgs at nixpkgs-weekly, which goes stale.
    # Run comma's packages from the nixpkgs this flake actually pins instead.
    environment.variables.COMMA_NIXPKGS_FLAKE =
      "github:NixOS/nixpkgs/${self.inputs.nixpkgs.rev}";
  };
}
