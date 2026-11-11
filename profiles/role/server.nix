# profiles/role/server.nix
#
# Baseline preset for headless / server environments across macOS & Linux.
{ lib, config, ... }: {
  # Weekly nix GC
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  virtualisation.oci-containers.backend = "podman";

  # Unified wired networking for servers. systemd-networkd applies only the
  # lexicographically first file matching an interface, so the generic one is
  # named 99- to stay a last resort: a host file (e.g. 10-eth0) wins silently.
  networking = {
    useDHCP = false;
    useNetworkd = true;
  };

  systemd.network = {
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

  # Power
  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";

  services.journald.settings.Journal = {
    SystemMaxUse = "200M";
    MaxRetentionSec = "21d";
  };

  systemd.oomd.enableSystemSlice = true;

  nix.optimise.automatic = true;
  nix.settings = {
    warn-dirty = false;
    use-xdg-base-directories = true;
    trusted-users = [ config.user.name "root" ];
    experimental-features = [ "nix-command" "flakes" ];
  };
}
