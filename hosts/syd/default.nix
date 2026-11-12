{
  system = "x86_64-linux";

  profiles = {
    user = "suspen";
    role = "workstation";
    networks = [ "pek" ];
  };

  modules = {
    networking.ssh.enable = true;

    shell = {
      fish.enable = true;
      nvim.enable = true;
      comma.enable = true;
      direnv.enable = true;
      git.enable = true;
    };
  };

  settings = {
    system.stateVersion = "26.11";
  };

  hardware = {
    # Register a build variant without importing it into the running system.
    image.modules.vhdx = ./image.nix;

    virtualisation.hypervGuest.enable = true;

    boot.loader = {
      # Use the EFI fallback path, independent of the VM's NVRAM entries.
      efi.canTouchEfiVariables = false;
      systemd-boot = {
        enable = true;
        configurationLimit = 5;
      };
    };

    boot.growPartition = true;

    fileSystems."/" = {
      device = "/dev/disk/by-label/syd";
      fsType = "btrfs";
      options = [ "compress=zstd" "subvol=root" ];
      autoResize = true;
    };

    fileSystems."/home" = {
      device = "/dev/disk/by-label/syd";
      fsType = "btrfs";
      options = [ "compress=zstd" "subvol=home" ];
      # User home creation happens during activation, before normal mounts.
      neededForBoot = true;
    };

    fileSystems."/nix" = {
      device = "/dev/disk/by-label/syd";
      fsType = "btrfs";
      options = [ "compress=zstd" "subvol=nix" ];
      neededForBoot = true;
    };

    fileSystems."/boot" = {
      device = "/dev/disk/by-label/SYD-ESP";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };
  };
}
