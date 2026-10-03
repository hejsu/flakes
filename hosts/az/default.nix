{
  system = "x86_64-linux";

  profiles = {
    user = "suspen";
    role = "server";
  };

  modules = {
    xdg.enable = true;

    shell = {
      fish.enable = true;
      nvim.enable = true;
      yazi.enable = true;
      git.enable = true;
    };

    sops = {
      enable = false;
    };

    services = {
      cliproxyapi.enable = false;
    };
  };


  ## Local config
  settings = { ss, ... }: {
    nix.optimise.automatic = true;
    nix.settings = {
      experimental-features = [ "nix-command" "flakes" ];

      auto-optimise-store = true;
    };

    # Workaround for https://github.com/NixOS/nix/issues/8502
    # (logrotate checkConfig fails when /var/log/journal doesn't exist yet)
    services.logrotate.checkConfig = false;

    networking.domain = "t0tivnfifftexijyidewzlguwg.lx.internal.cloudapp.net";

    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        ClientAliveInterval = 180;
      };
    };

    users.users.root.openssh.authorizedKeys.keys = [
      ss.keys.ss0
    ];

    user = {
      openssh.authorizedKeys.keys = [ ss.keys.ss0 ];
      initialHashedPassword = "$6$A/Ms/0m62sATO5ge$8dAjphC5IF5bKOa8W2/MEsVgW8HaL1lRZBeUi3ZO8hk1lkuU25HQVQ5m8zQobvtJZAk3NPRjeJq3zh7EQEdML0";
    };

    services.journald.settings.Journal.SystemMaxUse = "200M";

    system.stateVersion = "23.11";
  };

  hardware = { ... }: {
    virtualisation.hypervGuest.enable = true;
    zramSwap.enable = true;

    boot = {
      tmp.cleanOnBoot = true;
      kernelParams = [ "console=tty1" "console=ttyS0,115200" ];

      loader = {
        efi.efiSysMountPoint = "/boot/efi";
        grub = {
          efiSupport = true;
          configurationLimit = 10;
          efiInstallAsRemovable = true;
          device = "nodev";
        };
      };
    };

    fileSystems."/boot/efi" = {
      device = "/dev/disk/by-uuid/F086-A453";
      fsType = "vfat";
    };

    fileSystems."/" = {
      device = "/dev/sda1";
      fsType = "ext4";
    };

    swapDevices = [ { 
      device = "/swapfile"; 
      size = 8192; 
      discardPolicy = "once"; 
    } ];
  };
}
