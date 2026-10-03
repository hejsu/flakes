# profiles/role/server.nix
#
# Baseline preset for headless / server environments across macOS & Linux.
{ lib, ... }: {
  #### Housekeeping
  # Weekly nix GC
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # Weekly TRIM (SSD/VPS-friendly)
  services.fstrim.enable = true;

  #### Power
  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";

  services.journald.settings.Journal = {
    SystemMaxUse = "200M";
    MaxRetentionSec = "21d";
  };

  nix.optimise.automatic = true;
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];

    auto-optimise-store = true;

    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org" 
    ];
    trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };
}

