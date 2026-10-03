# profiles/role/server.nix
#
# Baseline preset for headless / server environments across macOS & Linux.
{ pkgs, lib, ... }: {
  #### Housekeeping
  # Weekly nix GC
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # Weekly TRIM (SSD/VPS-friendly)
  services.fstrim.enable = true;

  # Clear >1 month-old logs every week
  systemd = {
    services.clear-log = {
      description = "Clear >1 month-old logs every week";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.systemd}/bin/journalctl --vacuum-time=21d";
      };
    };
    timers.clear-log = {
      wantedBy = [ "timers.target" ];
      partOf = [ "clear-log.service" ];
      timerConfig.OnCalendar = "weekly UTC";
    };
  };

  #### Power
  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";
}

