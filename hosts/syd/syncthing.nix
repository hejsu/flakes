# Syncthing daemon for syd (LAN/Tailscale 4via6 only; devices & folders via GUI).
{ config, ... }: {
  networking.firewall = {
    allowedTCPPorts = [ 8384 22000 ];
    allowedUDPPorts = [ 22000 ];
  };

  sops.secrets."syncthing-gui-password" = {
    owner = config.user.name;
    mode = "0400";
    restartUnits = [ "syncthing-init.service" ];
  };

  services.syncthing = {
    enable = true;
    user = config.user.name;
    group = config.user.group;

    dataDir = config.home.dir;
    configDir = "${config.home.configDir}/syncthing";
    databaseDir = "${config.home.stateDir}/syncthing";

    guiAddress = "0.0.0.0:8384";
    guiPasswordFile = config.sops.secrets."syncthing-gui-password".path;

    overrideDevices = false;
    overrideFolders = false;

    settings = {
      gui = {
        user = config.user.name;
        # Allow access via http://syd.lan.aoran.eu.org:8384 over Tailscale 4via6.
        insecureSkipHostcheck = true;
      };

      options = {
        globalAnnounceEnabled = false;
        localAnnounceEnabled = false;
        natEnabled = false;
        relaysEnabled = false;
        urAccepted = -1;
      };
    };
  };
}
