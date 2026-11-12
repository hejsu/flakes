# Forward encrypted SS2022 TCP traffic; authentication and ACLs remain on echo.
{ ... }: {
  networking.nat = {
    enable = true;
    externalInterface = "eth0";

    forwardPorts = [{
      sourcePort = 38443;
      destination = "100.127.16.112:38443";
      proto = "tcp";
    }];
  };

  # Keep gateway return traffic on hws, without NATing other Tailnet traffic.
  networking.nftables.tables.hws-ss-snat = {
    family = "ip";
    content = ''
      chain postrouting {
        type nat hook postrouting priority srcnat + 10; policy accept;

        oifname "tailscale0" ip daddr 100.127.16.112 \
          tcp dport 38443 ct status dnat counter masquerade
      }
    '';
  };
}
