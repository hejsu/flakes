{ config, lib, pkgs, options, ... }:

let cfg = config.modules.services.cliproxyapi; stateDir = "${config.home.stateDir}/cliproxyapi"; in {
  options.modules.services.cliproxyapi = {
    enable = lib.mkEnableOption "CLIProxyAPI user service";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.cliproxyapi;
      description = "CLIProxyAPI package to run for the user service.";
    };

    configFile = lib.mkOption {
      type = lib.types.either lib.types.path lib.types.str;
      default = "${config.home.configDir}/cli-proxy-api/config.yaml";
      example = "/Users/alice/.config/cli-proxy-api/config.yaml";
      description = ''
        Path to the CLIProxyAPI config file that should be read directly.
        Note: Use a string path instead of a Nix path literal if you need
        the configuration to be mutable at runtime (e.g. hashed keys, web management).
      '';
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    (lib.optionalAttrs (options ? launchd) {
      system.activationScripts.cliproxyapi.text = ''
        mkdir -p "${config.home.configDir}/cli-proxy-api" "${stateDir}/logs" "${stateDir}/static"
        chown -R ${config.user.name}:staff "${config.home.configDir}/cli-proxy-api" "${stateDir}" 2>/dev/null || true
      '';

      launchd.user.agents.cliproxyapi = {
        serviceConfig = {
          Label = "org.nix-community.cliproxyapi";
          ProgramArguments = [
            (lib.getExe cfg.package)
            "-config"
            (toString cfg.configFile)
          ];
          RunAtLoad = true;
          KeepAlive = true;
          ThrottleInterval = 5;
          WorkingDirectory = stateDir;
          ProcessType = "Interactive";
          StandardOutPath = "${stateDir}/logs/stdout.log";
          StandardErrorPath = "${stateDir}/logs/stderr.log";
          EnvironmentVariables = {
            HOME = config.home.dir;
            PATH = "/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin";
            MANAGEMENT_STATIC_PATH = "${stateDir}/static";
          };
        };
      };
    })

    (lib.optionalAttrs (options ? systemd) {
      systemd.user.services.cliproxyapi = {
        Unit = {
          Description = "CLIProxyAPI user service";
          After = [ "network-online.target" ];
          Wants = [ "network-online.target" ];
        };
        Service = {
          ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${config.home.configDir}/cli-proxy-api ${stateDir}/logs ${stateDir}/static";
          ExecStart = "${lib.getExe cfg.package} -config ${toString cfg.configFile}";
          WorkingDirectory = stateDir;
          Restart = "on-failure";
          RestartSec = "5";
          Environment = [
            "HOME=${config.home.dir}"
            "MANAGEMENT_STATIC_PATH=${stateDir}/static"
          ];
        };
        Install = {
          WantedBy = [ "default.target" ];
        };
      };
    })
  ]);
}
