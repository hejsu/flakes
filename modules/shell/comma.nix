{ self, lib, config, ... }:
{
  imports = [ self.modules.nix-index-database.default ];

  options.modules.shell.comma.enable =
    lib.mkEnableOption "comma with the small nix-index database";

  config = lib.mkIf config.modules.shell.comma.enable {
    programs.nix-index-database.comma.enable = true;

    # The module points nix-locate at the full database; keep it small.
    programs.nix-index.package = self.inputs.nix-index-database.packages.nix-index-with-small-db;

    # Determinate's registry points nixpkgs at nixpkgs-weekly, which goes stale.
    # Run comma's packages from the nixpkgs this flake actually pins instead.
    environment.variables.COMMA_NIXPKGS_FLAKE =
      "github:NixOS/nixpkgs/${self.inputs.nixpkgs.rev}";
  };
}
