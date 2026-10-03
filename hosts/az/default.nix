{
  system = "x86_64-linux";

  profiles = {
    user = "suspen";
    role = "server";
    network = [ "ts0" ];
  };

  modules = {
    sops = {
      enable = true;
      ageKeyFile = "/var/lib/sops-nix/key.txt";

      secrets.tsAuthKey = {
        owner = "suspen";
        group = "users";
      };
    };

    shell = {
      fish.enable = true;
      nvim.enable = true;
      yazi.enable = true;
      git.enable = true;
    };

    dev = {
      nix.enable = true;
    };

    services = {
      ssh.enable = true;
    };
  };

  ## Local config
  settings = { ... }: {
    user = {
      initialHashedPassword = "$6$A/Ms/0m62sATO5ge$8dAjphC5IF5bKOa8W2/MEsVgW8HaL1lRZBeUi3ZO8hk1lkuU25HQVQ5m8zQobvtJZAk3NPRjeJq3zh7EQEdML0";
    };

    system.stateVersion = "23.11";
  };

  hardware = { ... }: {
    virtualisation.hypervGuest.enable = true;
    zramSwap = {
      enable = true;
      memoryPercent = 150;
      priority = 100; 
    };

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
