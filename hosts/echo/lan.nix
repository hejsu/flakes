{ ... }: {
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

  networking.firewall.interfaces.lan0 = {
    allowedTCPPorts = [ 53 ];
    allowedUDPPorts = [ 53 67 ];
  };
}
