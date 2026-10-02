{ config, lib, pkgs, ... }:

let cfg = config.services.cliproxyapi; in {
  options.services.cliproxyapi = {
    enable = lib.mkEnableOption "CLIProxyAPI user service (launchd)";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.cliproxyapi;
      description = "CLIProxyAPI package to run.";
    };

    configFile = lib.mkOption {
      type = lib.types.either lib.types.path lib.types.str;
      default = "${config.home.configDir}/cli-proxy-api/config.yaml";
      example = "/Users/alice/.config/cli-proxy-api/config.yaml";
      description = "Path to the CLIProxyAPI config file.";
    };
  };

  config = lib.mkIf cfg.enable {
    system.activationScripts.cliproxyapi.text = ''
      sudo -u ${config.user.name} mkdir -p "${config.home.configDir}/cli-proxy-api" "${config.home.stateDir}/cliproxyapi/static" "${config.home.dir}/Library/Logs/cliproxyapi"
    '';

    launchd.user.agents.cliproxyapi = {
      environment.MANAGEMENT_STATIC_PATH = "${config.home.stateDir}/cliproxyapi/static";

      serviceConfig = {
        ProgramArguments = [
          (lib.getExe cfg.package)
          "-config"
          (toString cfg.configFile)
        ];
        RunAtLoad = true;
        KeepAlive = true;
        ThrottleInterval = 5;
        WorkingDirectory = "${config.home.stateDir}/cliproxyapi";
        ProcessType = "Standard";
        StandardOutPath = "${config.home.dir}/Library/Logs/cliproxyapi/stdout.log";
        StandardErrorPath = "${config.home.dir}/Library/Logs/cliproxyapi/stderr.log";
      };
    };
  };
}
