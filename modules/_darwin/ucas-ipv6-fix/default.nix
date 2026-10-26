# UCAS campus network -- darwin IPv6 rogue RA fix.
#
# Disabled by default; enable per host through
# modules.services.ucas-ipv6-fix.enable.
{ config, lib, pkgs, ... }:

let
  cfg = config.modules.services.ucas-ipv6-fix;

  # Dorm subnet, in CIDR form. Compiled into the watcher, which compares en0's
  # address against it to decide whether the reconciler has anything to do.
  dormCidr = "192.168.77.0/24";

  # Listens on configd's dynamic store for State:/Network/Interface/en0/IPv4.
  # That key only holds address/mask/broadcast, so the callback fires exactly
  # when the interface really changed address -- no DNS/IPv6/Wi-Fi-scan churn.
  watcher = pkgs.stdenv.mkDerivation {
    pname = "ucas-ipv6-fix-watcher";
    version = "1";

    src = ./watcher.c;

    dontUnpack = true;

    buildPhase = ''
      runHook preBuild
      $CC -O2 -Wall -Wextra -DDORM_CIDR='"${dormCidr}"' -o ucas-ipv6-fix-watcher $src \
        -framework SystemConfiguration -framework CoreFoundation
      runHook postBuild
    '';

    installPhase = ''
      install -Dm755 ucas-ipv6-fix-watcher $out/bin/ucas-ipv6-fix-watcher
    '';
  };

  reconcile = pkgs.writeShellScript "ucas-ipv6-fix-reconcile" '' #bash
    set -eu

    anchor=com.apple/ucas-ipv6-fix
    mode="''${1:-other}"
    address="''${2:-}"

    if ! /sbin/pfctl -s info | grep -q "Status: Enabled"; then
      /sbin/pfctl -e
    fi

    # Anchors live in kernel memory, so reload on every boot. Doing it before
    # the branch also means the table exists for the flush below.
    /sbin/pfctl -a $anchor -f /etc/pf.anchors/ucas-ipv6-fix

    if [ "$mode" = dorm ]; then
      /sbin/pfctl -a $anchor -t rogue_routers -T replace fe80::1

      # Drop a default route the rogue router installed before pf took over.
      if /usr/sbin/netstat -rn -f inet6 | awk '$1 == "default" && $2 ~ /^fe80::1%/ { found = 1 } END { exit !found }'; then
        /sbin/route delete -inet6 -ifscope en0 default fe80::1%en0
      fi

      echo "[$(date)] dorm subnet (''${address:-?}), blocking rogue fe80::1 RA"
    else
      /sbin/pfctl -a $anchor -t rogue_routers -T flush
      echo "[$(date)] outside the dorm subnet (''${address:-none}), guard cleared"
    fi
  '';
in
{
  options.modules.services.ucas-ipv6-fix = {
    enable = lib.mkEnableOption "UCAS IPv6 rogue RA fix on darwin";
  };

  config = lib.mkIf cfg.enable {
    environment.etc."pf.anchors/ucas-ipv6-fix".text = ''
      table <rogue_routers> persist
      block in quick on en0 proto ipv6-icmp from <rogue_routers>
    '';

    launchd.daemons.ucas-ipv6-fix = {
      serviceConfig = {
        Label = "org.nixos.ucas-ipv6-fix";
        ProgramArguments = [
          "/bin/sh"
          "-c"
          "/bin/wait4path /nix/store && exec ${watcher}/bin/ucas-ipv6-fix-watcher ${reconcile}"
        ];
        KeepAlive = true;
        ProcessType = "Background";
        StandardErrorPath = "/var/log/ucas-ipv6-fix.err.log";
        StandardOutPath = "/var/log/ucas-ipv6-fix.out.log";
      };
    };
  };
}
