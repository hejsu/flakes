# UCAS campus network -- darwin backend (PF rogue RA filter & auto login).
{ self, config, lib, ... }:

let cfg = config.modules.services.ucasnet; in {
  config = lib.mkIf cfg.enable {
    environment.etc."pf.anchors/ucasnet-ra-guard".text = ''
      table <rogue_routers> persist
      block in quick on en0 proto ipv6-icmp from <rogue_routers>
    '';

    launchd.daemons.ucasnet-guard = {
      serviceConfig = {
        Label = "org.nixos.ucasnet-guard";
        RunAtLoad = true;
        WatchPaths = [
          "/var/run/resolv.conf"
          "/Library/Preferences/com.apple.wifi.known-networks.plist"
        ];
        StandardErrorPath = "/var/log/ucasnet-guard.err.log";
        StandardOutPath = "/var/log/ucasnet-guard.out.log";
      };

      script = '' #bash
        set -eu

        if ! /sbin/pfctl -s info | grep -q "Status: Enabled"; then
          /sbin/pfctl -e
        fi

        /sbin/pfctl -a "com.apple/ucasnet-ra-guard" -f /etc/pf.anchors/ucasnet-ra-guard

        if /sbin/ifconfig en0 | grep -q "broadcast 10.211.199.255"; then
          echo "[$(date)] Dorm subnet detected, blocking rogue fe80::1 RA..."
          /sbin/pfctl -a "com.apple/ucasnet-ra-guard" -t rogue_routers -T replace fe80::1

          if /usr/sbin/netstat -rn -f inet6 | awk '$1 == "default" && $2 ~ /^fe80::1%/ { found = 1 } END { exit !found }'; then
            /sbin/route delete -inet6 -ifscope en0 default fe80::1%en0
          fi
        else
          echo "[$(date)] Not the dorm subnet, clearing rogue router block..."
          /sbin/pfctl -a "com.apple/ucasnet-ra-guard" -t rogue_routers -T flush
        fi
      '';
    };

    launchd.daemons.ucasnet-login = {
      serviceConfig = {
        Label = "org.nixos.ucasnet-login";
        RunAtLoad = true;
        WatchPaths = [
          "/var/db/dhcpclient/leases/en0.plist"
          "/var/run/resolv.conf"
        ];

        StandardErrorPath = "/var/log/ucasnet-login.err.log";
        StandardOutPath = "/var/log/ucasnet-login.out.log";
      };

      script = '' #bash
        set -eu

        if /sbin/ifconfig en0 | grep -q "broadcast 10.211.199.255"; then
          echo "[$(date)] Dorm subnet detected, authenticating..."
          ${lib.getExe self.packages.bitsrun} -config "${config.sops.templates."bitsrun-config.yaml".path}"
        fi
      '';
    };
  };
}
