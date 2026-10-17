# profiles/network/ts0 -- join this machine to a tailnet ("tailscale 0")
{ config, ... }: {
  # TODO: how to adjust singbox and tailscale?
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "none";
    openFirewall = true;
    extraSetFlags = [ "--accept-dns=false" ];
  };
}
