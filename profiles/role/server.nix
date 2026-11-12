# profiles/role/server.nix
#
# Unattended maintenance and security policy for NixOS servers.
{ lib, ... }: {
  home.impure.enable = false;

  # Clean unattended machines, retaining two weeks of old system generations.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  security.protectKernelImage = true;

  virtualisation.oci-containers.backend = "podman";

  # Power
  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";

  services.journald.settings.Journal.MaxRetentionSec = "21d";

  systemd.oomd.enableSystemSlice = true;
}
