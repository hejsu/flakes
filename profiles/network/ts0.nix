# profiles/network/ts0 -- join this machine to a tailnet ("tailscale 0")
#
# Selects the "ts0" network. Machine-specific bits (e.g. the auth key)
# stay in the host's settings. Guarded to Linux since nix-darwin's
# services.tailscale has a different option set.
{ lib, pkgs, ... }: lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
    openFirewall = true;
    extraUpFlags = [ "--ssh" ];
  };
}
