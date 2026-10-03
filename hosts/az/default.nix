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
  settings = { config, ... }: {
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

    # Workaround for https://github.com/NixOS/nix/issues/8502
    # (logrotate checkConfig fails when /var/log/journal doesn't exist yet)
    services.logrotate.checkConfig = false;

    networking.domain = "t0tivnfifftexijyidewzlguwg.lx.internal.cloudapp.net";

    user = {
      initialHashedPassword = "$6$A/Ms/0m62sATO5ge$8dAjphC5IF5bKOa8W2/MEsVgW8HaL1lRZBeUi3ZO8hk1lkuU25HQVQ5m8zQobvtJZAk3NPRjeJq3zh7EQEdML0";
    };

    services.journald.settings.Journal.SystemMaxUse = "200M";

    # Machine-specific: the auth key comes from sops. Everything else about
    # tailscale lives in the network profile.
    services.tailscale.authKeyFile = config.sops.secrets.tsAuthKey.path;

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
