{ self, lib, config, pkgs, ... }:

let cfg = config.modules.shell.git; in {
  options.modules.shell.git = {
    enable = lib.mkEnableOption "Git and related tooling";
  };

  config = lib.mkIf cfg.enable {
    user.packages = with pkgs; [
      git
      gh
      # hut
      lazygit
    ];

    environment.shellAliases = {
      lg = "lazygit";
    };

    home.configFile = {
      "git/config".source = "${self.configDir}/git/config";
      "git/ignore".source = "${self.configDir}/git/ignore";

      "lazygit/config.yml".source = "${self.configDir}/lazygit/config.yml";
    };
  };
}
