{
  system = "x86_64-linux";

  profiles = {
    user = "suspen";
    role = "server";
    networks = [ "pek" "ts0" ];
  };

  modules = {
    services = {
      ssh.enable = true;
    };

    shell = {
      direnv.enable = true;
      git.enable = true;
      fish.enable = true;
      nvim.enable = true;
      yazi.enable = true;
    };
  };

  settings = { ... }: {
    user = {
      initialHashedPassword = "$6$8fKq2Zr9PmLxWvTy$o6W7AAu2IewTITRyufOT8R6i4WqeQxJLs.PZFUEHagBuOdxlAPhktx0OsLj.splluOmMsMmim0cGNjHrabxOW.";
    };

    networking = {
      useNetworkd = true;
      useDHCP = false;
    };

    systemd.network = {
      enable = true;
      wait-online.enable = false;
    };

    systemd.network.networks."10-eth0" = {
      matchConfig.Name = "eth0";
      networkConfig = {
        DHCP = "yes";
        IPv6PrivacyExtensions = "kernel";
      };
    };

    system.stateVersion = "26.11";
  };

  hardware = { ... }: {
    virtualisation.hypervGuest.enable = true;

    boot.loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot = {
        enable = true;
        configurationLimit = 10;
      };
    };

    fileSystems."/" = {
      device = "/dev/disk/by-uuid/7855b7f2-2287-42bd-b0cd-21846731f6ae";
      fsType = "btrfs";
      options = [ "compress=zstd" "subvol=root" ];
    };

    fileSystems."/home" = {
      device = "/dev/disk/by-uuid/7855b7f2-2287-42bd-b0cd-21846731f6ae";
      fsType = "btrfs";
      options = [ "compress=zstd" "subvol=home" ];
    };

    fileSystems."/nix" = {
      device = "/dev/disk/by-uuid/7855b7f2-2287-42bd-b0cd-21846731f6ae";
      fsType = "btrfs";
      options = [ "compress=zstd" "subvol=nix" ];
    };

    fileSystems."/boot" = {
      device = "/dev/disk/by-uuid/6F4E-E03F";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };
  };
}
