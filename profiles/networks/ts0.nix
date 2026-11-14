# profiles/network/ts0 -- join this machine to a tailnet ("tailscale 0")
{ config, ... }: {
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
    openFirewall = true;

    extraSetFlags = [
      "--accept-dns=true"
      "--accept-routes=true"
      "--operator=${config.user.name}"
    ];
  };
}
