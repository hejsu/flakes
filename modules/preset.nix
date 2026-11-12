# NixOS system defaults. Darwin excludes this module in its adaptation layer.
# Role-specific maintenance and security stay in profiles.
{ config, ... }:

{
  nix.optimise.automatic = true;
  nix.settings = {
    warn-dirty = false;
    use-xdg-base-directories = true;
    trusted-users = [ config.user.name "root" ];
    experimental-features = [ "nix-command" "flakes" ];
  };

  networking = {
    nftables.enable = true;
    useDHCP = false;
    useNetworkd = true;
  };

  systemd.network = {
    # networkd uses the first matching file. Host-specific rules such as
    # 10-eth0 take precedence over this wired DHCP fallback.
    networks."99-wired" = {
      matchConfig.Name = "eth* en*";
      networkConfig = {
        DHCP = "ipv4";
        IPv6AcceptRA = true;
      };
      linkConfig.RequiredForOnline = false;
    };

    wait-online.enable = false;
  };

  services.journald.settings.Journal.SystemMaxUse = "200M";
}
