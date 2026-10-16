# sing-box client (tun) fed by a remote subscription.
# Keeps `services.sing-box.settings` empty so nixpkgs points sing-box at
# $CONFIGURATION_DIRECTORY (/etc/sing-box) without embedding config in store.
{ config, lib, pkgs, ... }:

let cfg = config.modules.services.singbox; in {
  options.modules.services.singbox = {
    enable = lib.mkEnableOption "sing-box client (tun) fed by a subscription";
  };

  config = lib.mkIf cfg.enable {
    assertions = [{
      assertion = config.services.sing-box.settings == { };
      message = ''
        modules.services.singbox: services.sing-box.settings must stay empty --
        that is what makes sing-box read /etc/sing-box. Setting it would send
        sing-box to $RUNTIME_DIRECTORY and ignore the fetched /etc/sing-box/config.json.
      '';
    }];

    sops.secrets."singbox-suburl" = {
      restartUnits = [ "singbox-subscription.service" ];
    };

    services.sing-box.enable = true;

    # Ensure configDir exists before the initial fetch runs.
    systemd.tmpfiles.rules = [ "d /etc/sing-box 0755 root root -" ];

    # Defer startup until initial config is fetched.
    systemd.services.sing-box.unitConfig.ConditionPathExists = "/etc/sing-box/config.json";

    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv4.conf.all.rp_filter" = 2;
      "net.ipv4.conf.default.rp_filter" = 2;
    };

    networking.firewall.trustedInterfaces = [ "tun0" ];
 
    systemd.services.singbox-subscription = {
      description = "Fetch sing-box config from subscription";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      unitConfig = {
        StartLimitIntervalSec = 0;
      };

      serviceConfig = {
        Type = "oneshot";
        Restart = "on-failure";
        RestartSec = 30;
      };

      script = ''
        set -euo pipefail

        url=$(${lib.getExe' pkgs.coreutils "tr"} -d '[:space:]' < ${lib.escapeShellArg config.sops.secrets."singbox-suburl".path})

        # Download without .json suffix so sing-box `-C` ignores partial files.
        tmp=$(${lib.getExe' pkgs.coreutils "mktemp"} -p /etc/sing-box .config.json.XXXXXXXX)
        trap '${lib.getExe' pkgs.coreutils "rm"} -f "$tmp"' EXIT

        ${lib.getExe pkgs.curl} \
          --fail --silent --show-error --location \
          --user-agent "sing-box" \
          --retry 3 --retry-delay 5 --connect-timeout 10 --max-time 60 \
          --output "$tmp" \
          -- "$url"

        # Validate syntax before replacing the active config.
        ${lib.getExe pkgs.sing-box} check -c "$tmp"

        ${lib.getExe' pkgs.coreutils "install"} -m 0640 -g sing-box "$tmp" /etc/sing-box/config.json

        ${lib.getExe' config.systemd.package "systemctl"} --no-block restart sing-box.service
      '';
    };

    systemd.timers.singbox-subscription = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "10min";
      };
    };
  };
}
