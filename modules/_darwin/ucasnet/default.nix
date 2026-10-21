# UCAS campus network -- darwin backend (PF rogue RA guard & auto login).
{ self, config, lib, pkgs, ... }:

let
  cfg = config.modules.services.ucasnet;

  # Listens on configd's dynamic store for State:/Network/Interface/en0/IPv4.
  # That key only holds address/mask/broadcast, so the callback fires exactly
  # when the interface really changed address -- no DNS/IPv6/Wi-Fi-scan churn.
  watcher = pkgs.stdenv.mkDerivation {
    pname = "ucasnet-watcher";
    version = "1";

    src = ./watcher.c;

    dontUnpack = true;

    buildPhase = ''
      runHook preBuild
      $CC -O2 -Wall -Wextra -o ucasnet-watcher $src \
        -framework SystemConfiguration -framework CoreFoundation
      runHook postBuild
    '';

    installPhase = ''
      install -Dm755 ucasnet-watcher $out/bin/ucasnet-watcher
    '';
  };

  reconcile = pkgs.writeShellScript "ucasnet-reconcile" '' #bash
    set -eu

    dorm=10.211.199.255
    anchor=com.apple/ucasnet-ra-guard

    broadcast="''${1:-}"

    if ! /sbin/pfctl -s info | grep -q "Status: Enabled"; then
      /sbin/pfctl -e
    fi

    # Anchors live in kernel memory, so reload on every boot. Doing it before
    # the branch also means the table exists for the flush below.
    /sbin/pfctl -a $anchor -f /etc/pf.anchors/ucasnet-ra-guard

    if [ "$broadcast" = "$dorm" ]; then
      /sbin/pfctl -a $anchor -t rogue_routers -T replace fe80::1

      # Drop a default route the rogue router installed before pf took over.
      if /usr/sbin/netstat -rn -f inet6 | awk '$1 == "default" && $2 ~ /^fe80::1%/ { found = 1 } END { exit !found }'; then
        /sbin/route delete -inet6 -ifscope en0 default fe80::1%en0
      fi

      echo "[$(date)] dorm subnet, blocking rogue fe80::1 RA"

      ${lib.getExe self.packages.bitsrun} -config "${config.sops.templates."bitsrun-config.yaml".path}"
    else
      /sbin/pfctl -a $anchor -t rogue_routers -T flush
      echo "[$(date)] not the dorm subnet, guard cleared"
    fi
  '';
in {
  config = lib.mkIf cfg.enable {
    environment.etc."pf.anchors/ucasnet-ra-guard".text = ''
      table <rogue_routers> persist
      block in quick on en0 proto ipv6-icmp from <rogue_routers>
    '';

    launchd.daemons.ucasnet = {
      serviceConfig = {
        Label = "org.nixos.ucasnet";
        ProgramArguments = [
          "/bin/sh"
          "-c"
          "/bin/wait4path /nix/store && exec ${watcher}/bin/ucasnet-watcher ${reconcile}"
        ];
        KeepAlive = true;
        ProcessType = "Background";
        StandardErrorPath = "/var/log/ucasnet.err.log";
        StandardOutPath = "/var/log/ucasnet.out.log";
      };
    };
  };
}
