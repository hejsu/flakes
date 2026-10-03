{ config, lib, pkgs, options, ... }:

let cfg = config.modules.services.cliproxyapi; in {
  options.modules.services.cliproxyapi = {
    enable = lib.mkEnableOption "CLIProxyAPI user service";

    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Upstream settings for CLIProxyAPI (NixOS).";
    };

    configFile = lib.mkOption {
      type = lib.types.either lib.types.path lib.types.str;
      default = "${config.home.configDir}/cli-proxy-api/config.yaml";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    # NixOS: settings are rendered to /var/lib/cliproxyapi/config.yaml
    (lib.optionalAttrs (options.services.cliproxyapi ? settings) {
      services.cliproxyapi = {
        enable = true;
        inherit (cfg) settings;
        package = pkgs.cliproxyapi;
        openFirewall = true;
      };
    })

    # macOS launchd: custom module takes a config file path
    (lib.optionalAttrs (options.services.cliproxyapi ? configFile) {
      services.cliproxyapi = {
        enable = true;
        package = pkgs.cliproxyapi;
        configFile = cfg.configFile;
      };
    })
  ]);
}
