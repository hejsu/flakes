{ config, lib, pkgs, ... }:

let cfg = config.modules.services.cliproxyapi; in {
  options.modules.services.cliproxyapi = {
    enable = lib.mkEnableOption "CLIProxyAPI user service";

    configFile = lib.mkOption {
      type = lib.types.either lib.types.path lib.types.str;
      default = "${config.home.configDir}/cli-proxy-api/config.yaml";
    };
  };

  config = lib.mkIf cfg.enable {
    services.cliproxyapi = {
      enable = true;
      package = pkgs.cliproxyapi;
      configFile = cfg.configFile;
    };
  };
}