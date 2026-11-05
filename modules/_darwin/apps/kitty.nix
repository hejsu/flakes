{ self, lib, config, ... }:

let cfg = config.modules.apps.kitty; in {
  options.modules.apps.kitty.enable =
    lib.mkEnableOption "kitty terminal, installed from the cask";

  config = lib.mkIf cfg.enable {
    homebrew.casks = [ "kitty" ];
    home.configFile."kitty".source = "${self.configDir}/kitty";
    environment.variables.TERMINAL = "kitty";
  };
}
