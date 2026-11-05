{ self, lib, config, ... }:

let cfg = config.modules.apps.zed; in {
  options.modules.apps.zed.enable =
    lib.mkEnableOption "Zed, installed from the cask";

  config = lib.mkIf cfg.enable {
    homebrew.casks = [ "zed" ];
    home.configFile."zed/settings.json".source = "${self.configDir}/zed/settings.json";
  };
}
