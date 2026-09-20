{ ss, pkgs, lib, config, ... }:

let cfg = config.modules.shell.yazi; in {
  options.modules.shell.yazi = {
    enable = lib.mkEnableOption "Yazi file manager";
  };

  config = lib.mkIf cfg.enable {
    user.packages = [ pkgs.yazi ];

    environment.shellAliases = {
      yz = "yazi";
    };

    home.configFile."yazi".source = "${ss.configDir}/yazi";

    modules.shell.fish.rcFiles = [ "${ss.configDir}/yazi/y.fish" ];
  };
}
