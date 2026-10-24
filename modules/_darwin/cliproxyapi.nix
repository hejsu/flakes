# CLIProxyAPI -- darwin backend (launchd user agent).
#
# Only the `enable` switch is shared with modules/services/cliproxyapi.nix; the
# systemd half there is NixOS-only. The config lives in ~/.config because the
# agent runs as the logged-in user, which can read it by definition.
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
          "${config.home.configDir}/cli-proxy-api/config.yaml"
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
