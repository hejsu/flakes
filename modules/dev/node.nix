# Node.js runtime.
{ lib, config, pkgs, ... }:

let cfg = config.modules.dev.node; in {
  options.modules.dev.node = {
    enable = lib.mkEnableOption "Node.js runtime";
  };

  config = lib.mkIf cfg.enable {
    user.packages = with pkgs; [
      nodejs
    ];

    environment.variables = {
      NPM_CONFIG_PREFIX = "${config.home.dataDir}/npm";
    };

    home.sessionPath = [ "${config.home.dataDir}/npm/bin" ];
  };
}
