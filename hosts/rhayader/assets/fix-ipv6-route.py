#!/usr/bin/env python3
"""Dorm (Pineapple) only: pin 2000::/3 via <prefix>::1.

The Shortcut restricts this to the dorm SSID. The probe is only for
logging; the route is kept even if it fails. Use --clear when leaving.
"""

import ipaddress
import re
import socket
import ssl
import subprocess
import sys
import time

ROUTE, IFACE = "2000::/3", "en0"
PROBES = (
    ("www.tsinghua.edu.cn", "2402:f000:1:402:101:6:15:66"),
    ("www.edu.cn", "2001:da8:20d:22::10"),
)


def run(*cmd: str, timeout: float = 10) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired as exc:
        return subprocess.CompletedProcess(cmd, 124, "", str(exc))


def delete_route() -> None:
    run("/sbin/route", "delete", "-inet6", ROUTE, "-ifscope", IFACE, timeout=5)
    run("/sbin/route", "delete", "-inet6", ROUTE, timeout=5)


def slaac_gateway() -> str | None:
    out = run("/sbin/ifconfig", IFACE).stdout
    for addr, plen in re.findall(r"inet6\s+(\S+)\s+prefixlen\s+(\d+)", out):
        try:
            ip = ipaddress.IPv6Address(addr.split("%")[0])
        except ValueError:
            continue
        if ip.is_global:
            net = ipaddress.IPv6Network(
                f"{ip}/{min(int(plen), 64)}", strict=False
            )
            return str(net.network_address + 1)
    return None


def https_ok(host: str, addr: str, timeout: float = 4.0) -> bool:
    try:
        with socket.create_connection((addr, 443), timeout=timeout) as sock:
            with ssl.create_default_context().wrap_socket(
                sock, server_hostname=host
            ):
                return True
    except (OSError, ssl.SSLError):
        return False


def probe() -> str | None:
    return next((addr for host, addr in PROBES if https_ok(host, addr)), None)


def main() -> int:
    if "--clear" in sys.argv[1:]:
        delete_route()
        print("cleared")
        return 0

    gateway = None
    for _ in range(15):
        gateway = slaac_gateway()
        if gateway:
            break
        time.sleep(1)

    if not gateway:
        print(f"no global IPv6 address on {IFACE}")
        return 1

    delete_route()
    result = run("/sbin/route", "add", "-inet6", ROUTE, gateway, timeout=5)
    if result.returncode != 0:
        print(f"route add failed via {gateway}: {result.stderr.strip()}")
        return 1

    hit = probe()
    print(f"pinned {ROUTE} via {gateway}: {hit or 'probe failed, route kept'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
