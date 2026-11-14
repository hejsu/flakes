{ lib, ... }: {
  services.tailscale = {
    # Route the LAN while retaining loose RPF for sing-box's policy routing.
    useRoutingFeatures = lib.mkForce "both";
    # 4via6 site 1 maps the LAN without conflicting with clients' local subnets.
    extraSetFlags = [ "--advertise-routes=fd7a:115c:a1e0:b1a:0:1:c0a8:a00/120" ];
  };

  systemd.network.links."10-lan0" = {
    matchConfig.MACAddress = "00:15:5d:02:65:07";
    linkConfig.Name = "lan0";
  };

  systemd.network.networks."10-lan0" = {
    matchConfig.Name = "lan0";

    address = [ "192.168.10.1/24" ];

    networkConfig = {
      DHCP = "no";
      IPv6AcceptRA = false;
      DHCPServer = true;
    };

    dhcpServerConfig = {
      PoolOffset = 100;
      PoolSize = 100;

      EmitRouter = true;
      Router = "192.168.10.1";

      EmitDNS = true;
      DNS = [ "192.168.10.1" ];
    };

    dhcpServerStaticLeases = [
      {
        MACAddress = "00:15:5d:02:65:06";
        Address = "192.168.10.2";
      }
      {
        MACAddress = "00:15:5d:02:65:09";
        Address = "192.168.10.10";
      }
    ];
  };

  services.resolved.settings = {
    Resolve.DNSStubListenerExtra = "192.168.10.1";
  };

  networking.nat = {
    enable = true;
    externalInterface = "eth0";
    internalIPs = [ "192.168.10.0/24" ];
  };

  # LAN-initiated Tailnet connections use echo's identity. This also lets
  # TailVIP Services hosted on echo reply through the host's conntrack/NAT.
  # Tailscale's built-in subnet SNAT handles the opposite direction.
  networking.nftables.tables.echo-lan-tailnet-snat = {
    family = "ip";
    content = ''
      chain postrouting {
        type nat hook postrouting priority srcnat + 10; policy accept;

        iifname "lan0" oifname "tailscale0" \
          ip saddr 192.168.10.0/24 ip daddr 100.64.0.0/10 counter masquerade
      }
    '';
  };

  # Hyper-V Internal LAN contains our own Windows host and VMs.
  networking.firewall.trustedInterfaces = [ "lan0" ];

  networking.firewall.interfaces.lan0 = {
    allowedTCPPorts = [ 53 ];
    allowedUDPPorts = [ 53 67 ];
  };
}
