{ ss, config, lib, ... }:

let cfg = config.modules.apps.zed; in {
  options.modules.apps.zed.enable = lib.mkEnableOption "Zed editor";

  config = lib.mkIf cfg.enable {
    home.configFile."zed/settings.json".source = "${ss.configDir}/zed/settings.json";
    homebrew.casks = [ "zed" ];
  };
}

