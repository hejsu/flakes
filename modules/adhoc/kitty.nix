{ ss, config, lib, ... }:

let cfg = config.modules.apps.kitty; in {
  options.modules.apps.kitty.enable = lib.mkEnableOption "Kitty terminal emulator";

  config = lib.mkIf cfg.enable {
    home.configFile."kitty".source = "${ss.configDir}/kitty";
    homebrew.casks = [ "kitty" ];
  };
}

