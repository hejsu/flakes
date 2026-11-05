#!/bin/sh
# Shortcuts decides when to apply or clear the dorm IPv6 guard.
set -eu
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

anchor=com.apple/ucas-ipv6-fix
router=fe80::7625:8aff:fe00:f1ab

if [ "$#" -eq 1 ] && [ "$1" = clear ]; then
  /sbin/pfctl -a "$anchor" -F all
  exit 0
fi
if [ "$#" -ne 0 ]; then
  echo "Usage: ucas-ipv6-ctl [clear]" >&2
  exit 1
fi

if ! /sbin/pfctl -s info | grep -q "Status: Enabled"; then
  /sbin/pfctl -e
fi

# Trust only the dorm router. macOS calls the RA type "routeradv".
/sbin/pfctl -a "$anchor" -f - <<EOF
table <allowed_routers> persist { $router }
pass in quick on en0 inet6 proto ipv6-icmp from <allowed_routers>
block in quick on en0 inet6 proto ipv6-icmp icmp6-type routeradv
EOF

# Remove untrusted default routes installed before the rules loaded.
/usr/sbin/netstat -rn -f inet6 | awk '$1 == "default" && $2 ~ /%en0$/ { print $2 }' |
while read -r gw; do
  case "$gw" in
    "$router"%*) ;;
    *) /sbin/route delete -inet6 -ifscope en0 default "$gw" || true ;;
  esac
done
