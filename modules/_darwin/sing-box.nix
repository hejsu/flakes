{ config, lib, pkgs, ... }:

let
  cfg = config.services.sing-box;

  configDir = "/Library/Application Support/sing-box";
  stateDir = "/var/db/sing-box";
  logDir = "/Library/Logs/sing-box";
  configFile = "${configDir}/config.json";
in
{
  options.services.sing-box = {
    enable = lib.mkEnableOption "sing-box system daemon (launchd)";

    subscriptionUrl = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "https://example.com/api/v1/client/subscribe?token=xxx";
      description = ''
        Subscription URL used to fetch the config on first start.
        The updater daemon polls it on a schedule and reloads sing-box.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.sing-box ];

    system.activationScripts.sing-box.text = ''
      mkdir -p "${configDir}" "${stateDir}" "${logDir}"
    '';

    launchd.daemons.sing-box = {
      command = toString (pkgs.writeShellScript "run-sing-box" ''
        mkdir -p "${configDir}" "${stateDir}" "${logDir}"

        if [ ! -f "${configFile}" ]; then
          ${lib.getExe pkgs.curl} -fsSL "${cfg.subscriptionUrl}" -o "${configFile}"
        fi

        exec ${lib.getExe pkgs.sing-box} -D "${stateDir}" -C "${configDir}" run
      '');

      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        ThrottleInterval = 5;
        WorkingDirectory = stateDir;
        StandardOutPath = "${logDir}/output.log";
        StandardErrorPath = "${logDir}/error.log";
      };
    };

    launchd.daemons.sing-box-updater = {
      command = toString (pkgs.writeShellScript "update-sing-box" ''
        set -eu

        TEMP="$(${lib.getExe' pkgs.coreutils "mktemp"})"
        trap 'rm -f "$TEMP"' EXIT

        if ${lib.getExe pkgs.curl} -fsSL "${cfg.subscriptionUrl}" -o "$TEMP" \
          && ${lib.getExe pkgs.sing-box} check -c "$TEMP"; then
          ${lib.getExe' pkgs.coreutils "install"} -m 600 "$TEMP" "${configFile}"
          /usr/bin/killall -HUP sing-box || true
        fi
      '');

      serviceConfig = {
        StartCalendarInterval = [{ Hour = 4; Minute = 0; }];
        StandardOutPath = "${logDir}/updater.log";
        StandardErrorPath = "${logDir}/updater-error.log";
      };
    };
  };
}
