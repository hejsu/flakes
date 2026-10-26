# UCAS campus network -- darwin IPv6 router guard (plus the dorm login).
#
# Disabled by default; enable per host through
# modules.services.ucas-ipv6-fix.enable. Enabling it also requires
# modules.services.ucasrun, which owns the bitsrun config this module spawns.
{ self, config, lib, pkgs, ... }:

let
  cfg = config.modules.services.ucas-ipv6-fix;

  # Dorm subnet, in CIDR form. Compiled into the watcher, which compares en0's
  # address against it to decide whether the reconciler has anything to do.
  dormCidr = "10.211.192.0/21";

  # The only router allowed to advertise on the dorm link. The other boxes
  # there are either dead (fe80::a:1 advertises a default route but never
  # answers NS), misconfigured (fe80::96a6… runs M=1/O=1 DHCPv6 with no prefix
  # and proxies NDP for other hosts), or somebody else's router plugged into
  # the same switch. Everything else is denied, so this is an allowlist.
  allowedRouters = [ "fe80::7625:8aff:fe00:f1ab" ];

  # "fe80::7625…%*" -- shell pattern used below to keep trusted default routes.
  allowedPattern = lib.concatMapStringsSep "|" (r: "${r}%*") allowedRouters;

  # The portal login is its own script so it can be run by hand while debugging
  # the dorm Wi-Fi; the reconciler only fires it in the background.
  bitsrunLogin = pkgs.writeShellScript "ucas-ipv6-fix-bitsrun" ''
    set -eu

    log=/var/log/ucas-ipv6-fix-bitsrun.log
    echo "[$(date)] login start"
    ${lib.getExe' pkgs.coreutils "timeout"} 120 ${lib.getExe self.packages.bitsrun} \
      -config ${config.sops.templates."bitsrun-config.yaml".path} >>"$log" 2>&1 ||
      echo "[$(date)] login exited $?"
  '';

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

    if [ "$mode" = dorm ]; then
      # One login per dorm entry, independent of whether the guard loads: a pf
      # syntax error must not leave us logged out. Detached so a slow or failing
      # portal cannot wedge the watcher; the script caps bitsrun at 120s.
      ( ${bitsrunLogin} >/dev/null 2>&1 || true ) &

      # Loading the anchor resets its tables, so fill them afterwards.
      /sbin/pfctl -a $anchor -f /etc/pf.anchors/ucas-ipv6-fix
      /sbin/pfctl -a $anchor -t allowed_routers -T replace ${lib.escapeShellArgs allowedRouters}

      # Drop default routes installed by anything we do not trust. Without this
      # they keep blackholing traffic until their RA lifetime runs out.
      /usr/sbin/netstat -rn -f inet6 | awk '$1 == "default" && $2 ~ /%en0$/ { print $2 }' |
      while read -r gw; do
        case "$gw" in
          ${allowedPattern}) ;;
          *) /sbin/route delete -inet6 -ifscope en0 default "$gw" || true ;;
        esac
      done

      echo "[$(date)] dorm subnet (''${address:-?}), whitelisting ${lib.concatStringsSep " " allowedRouters}"
    else
      # Outside the dorm nothing is guarded: drop rules and tables entirely, so
      # an empty allowlist can never turn into "block every RA".
      /sbin/pfctl -a $anchor -F all
      echo "[$(date)] outside the dorm subnet (''${address:-none}), guard cleared"
    fi
  '';
in {
  options.modules.services.ucas-ipv6-fix = {
    enable = lib.mkEnableOption "UCAS IPv6 router guard on darwin";
  };

  config = lib.mkIf cfg.enable {
    assertions = [{
      assertion = config.modules.services.ucasrun.enable;
      message = "modules.services.ucas-ipv6-fix: enable modules.services.ucasrun too; it owns the bitsrun config this module spawns.";
    }];

    environment.etc."pf.anchors/ucas-ipv6-fix".text = ''
      table <allowed_routers> persist

      # macOS spells it "routeradv" (see icmp6(4)); "routeradvert" is the
      # OpenBSD/Linux spelling and makes pfctl reject the whole file. The
      # explicit inet6 is required: pf refuses icmp6-type without an af.
      pass  in quick on en0 inet6 proto ipv6-icmp from <allowed_routers>
      block in quick on en0 inet6 proto ipv6-icmp icmp6-type routeradv
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
