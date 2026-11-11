# sing-box runtime with optional subscription updates.
# Host-specific TUN and firewall settings live alongside the host network config.
{ config, lib, pkgs, ... }:

let cfg = config.modules.networking.singbox; in {
  options.modules.networking.singbox = {
    enable = lib.mkEnableOption "sing-box";
    subscription.enable = lib.mkEnableOption "sing-box subscription updates";
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      services.sing-box = {
        enable = true;
        # A baseline settings value selects upstream's runtime configuration directory.
        settings.log.level = lib.mkDefault "info";
      };
    }

    (lib.mkIf cfg.subscription.enable {
      sops.secrets."singbox-suburl" = { };

      systemd.services.sing-box.serviceConfig.ExecStartPre = lib.mkAfter [
        (pkgs.writeShellScript "sing-box-prepare-client" ''
          set -eu
          umask 077

          client="$STATE_DIRECTORY/client.json"
          if [ ! -e "$client" ]; then
            if [ -f /etc/sing-box/config.json ]; then
              # Preserve the subscription when migrating from the previous directory.
              ${pkgs.coreutils}/bin/install -m 0600 /etc/sing-box/config.json "$client"
            else
              (set -C; printf '{}\n' > "$client") || test -f "$client"
            fi
          fi

          ${pkgs.coreutils}/bin/ln -sfnT \
            "$client" "$RUNTIME_DIRECTORY/z-client.json"
        '')
      ];

      systemd.services.singbox-subscription = {
        description = "Refresh sing-box client configuration";
        # Configuration switches preserve the scheduled or manually started job.
        restartIfChanged = false;
        stopIfChanged = false;
        after = [ "network-online.target" "sing-box.service" ];
        wants = [ "network-online.target" "sing-box.service" ];
        path = [ pkgs.coreutils pkgs.curl config.services.sing-box.package ];

        serviceConfig = {
          Type = "oneshot";
          UMask = "0077";
        };

        script = ''
          set -euo pipefail

          state=/var/lib/sing-box
          url=$(tr -d '[:space:]' \
            < ${lib.escapeShellArg config.sops.secrets."singbox-suburl".path})

          tmp=$(mktemp "$state/.client.XXXXXXXX")
          trap 'rm -f -- "$tmp"' EXIT
          trap 'exit 130' INT
          trap 'exit 143' TERM

          curl --fail --silent --show-error --location \
            --user-agent "sing-box" \
            --retry 3 --retry-delay 5 --connect-timeout 10 --max-time 60 \
            --output "$tmp" -- "$url"

          # Validate the gateway together with the candidate subscription.
          if ! sing-box -D "$state" \
            -c /run/sing-box/config.json -c "$tmp" check \
            > "$state/subscription-check.log" 2>&1; then
            echo "Subscription validation failed; current configuration retained." >&2
            exit 1
          fi

          chown sing-box:sing-box "$tmp"
          chmod 0600 "$tmp"
          mv -fT -- "$tmp" "$state/client.json"

          ${lib.getExe' config.systemd.package "systemctl"} \
            --no-block try-restart sing-box.service
        '';
      };

      systemd.timers.singbox-subscription = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "daily";
          Persistent = false;
          RandomizedDelaySec = "10min";
        };
      };
    })
  ]);
}
