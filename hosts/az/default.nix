{
  system = "x86_64-linux";

  profiles = {
    user = "suspen";
    role = "server";
    networks = [ "tyo" "ts0" ];
  };

  modules = {
    sops.enable = true;

    shell = {
      fish.enable = true;
    };

    networking = {
      ssh.enable = true;
    };
  };

  ## Local config
  settings = { ... }: {
    networking = {
      enableIPv6 = true;

      firewall = {
        enable = true;
        allowedTCPPorts = [ 22 80 443 ];
      };
    };

    user.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHJH2kt92wMUL0HavbaoyDqYQA0pjusb54lIXIQSEg7H"
    ];

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
      kernelParams = [
        "console=ttyS0,115200"
        "console=tty1"
      ];

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

    swapDevices = [{
      device = "/swapfile";
      size = 8192;
      discardPolicy = "once";
    }];
  };
}
