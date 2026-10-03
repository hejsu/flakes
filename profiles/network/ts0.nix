# profiles/network/ts0 -- join this machine to a tailnet ("tailscale 0")
{ config, ... }: {
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "none";
    openFirewall = true;
    authKeyFile = config.sops.secrets.tsAuthKey.path;
  };
}
