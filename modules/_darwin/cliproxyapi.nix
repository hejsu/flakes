# CLIProxyAPI -- darwin backend (launchd user agent).
#
# The switch and `configFile` come from the shared module in
# modules/services/cliproxyapi.nix; its systemd half is dropped here by
# modules/_darwin/parity.nix.
{ self, config, lib, ... }:

let cfg = config.modules.services.cliproxyapi; in {
  config = lib.mkIf cfg.enable {
    system.activationScripts.cliproxyapi.text = ''
      sudo -u ${config.user.name} mkdir -p "${config.home.configDir}/cli-proxy-api" "${config.home.stateDir}/cliproxyapi/static" "${config.home.dir}/Library/Logs/cliproxyapi"
    '';

    launchd.user.agents.cliproxyapi = {
      environment.MANAGEMENT_STATIC_PATH = "${config.home.stateDir}/cliproxyapi/static";

      serviceConfig = {
        ProgramArguments = [
          (lib.getExe self.inputs.llm-agents.packages.cli-proxy-api)
          "-config"
          "${cfg.configFile}"
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
