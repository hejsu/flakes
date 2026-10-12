# profiles/role/server.nix
#
# Baseline preset for headless / server environments across macOS & Linux.
{ lib, ... }: {
  # Weekly nix GC
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  # Weekly TRIM (SSD/VPS-friendly)
  services.fstrim.enable = true;

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
    trusted-users = [ "suspen" "root" ];
    experimental-features = [ "nix-command" "flakes" ];
  };
}

