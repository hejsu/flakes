{
  system = "x86_64-linux";

  profiles = {
    user = "suspen";
    role = "server";
  };

  modules = {
    services = {
      ssh.enable = true;
    };

    shell = {
      fish.enable = true;
      nvim.enable = true;
      yazi.enable = true;
      git.enable = true;
    };
  };

  settings = { ... }: {
    user = {
      initialHashedPassword = "$6$8fKq2Zr9PmLxWvTy$o6W7AAu2IewTITRyufOT8R6i4WqeQxJLs.PZFUEHagBuOdxlAPhktx0OsLj.splluOmMsMmim0cGNjHrabxOW.";
    };

    system.stateVersion = "26.11";

    networking.networkmanager.enable = true;

    nix.settings = {
      substituters = [
        "https://mirrors.cernet.edu.cn/nix-channels/store"
        "https://mirrors.ustc.edu.cn/nix-channels/store"
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };
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
