# Syncthing daemon for rhayader (macOS); same interface as NixOS hosts/syd/syncthing.nix.
{ config, ... }: {
  sops.secrets."syncthing-gui-password" = {
    owner = config.user.name;
    mode = "0400";
  };

  services.syncthing = {
    enable = true;
    dataDir = config.home.dir;
    configDir = "${config.home.configDir}/syncthing";
    databaseDir = "${config.home.stateDir}/syncthing";

    guiAddress = "127.0.0.1:8384";
    guiPasswordFile = config.sops.secrets."syncthing-gui-password".path;

    overrideDevices = false;
    overrideFolders = false;

    settings = {
      gui.user = config.user.name;

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
