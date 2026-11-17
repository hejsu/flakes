# Tailscale DERP and STUN relay (hws only).
{ ... }: {
  services.caddy.virtualHosts."https://derp.aoran.eu.org:33443".extraConfig = ''
    reverse_proxy 127.0.0.1:8081
  '';

  services.tailscale.derper = {
    enable = true;
    domain = "derp.aoran.eu.org";
    configureNginx = false;
    port = 8081;
    stunPort = 3478;
    openFirewall = true;
    verifyClients = true;
  };

  networking.firewall.allowedTCPPorts = [ 33443 ];
}
