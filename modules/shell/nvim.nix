{ ss, pkgs, lib, config, ... }:

let cfg = config.modules.shell.nvim; in {
  options.modules.shell.nvim = {
    enable = lib.mkEnableOption "Neovim";
  };

  config = lib.mkIf cfg.enable {
    user.packages = [
      pkgs.neovim
      pkgs.tree-sitter
    ];

    environment.variables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };

    environment.shellAliases = {
      v = "nvim";
    };

    home.configFile.nvim.source = "${ss.configDir}/nvim";
  };
}
