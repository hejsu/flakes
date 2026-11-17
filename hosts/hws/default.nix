{
  system = "x86_64-linux";

  includes = [
    ./derp.nix
    ./gatus.nix
    ./ss-gateway.nix
  ];

  profiles = {
    user = "suspen";
    role = "server";
    networks = [ "pek" "ts0" ];
  };

  modules = {
    sops.enable = true;

    shell = {
      fish.enable = true;
      comma.enable = true;
    };

    services = {
      caddy.enable = true;
      openssh.enable = true;
    };
  };

  ## Local config
  settings = { ... }: {
    systemd.network.networks."99-wired" = {
      networkConfig.DNS = [
        "223.5.5.5"
        "119.29.29.29"
      ];
      dhcpV4Config.UseDNS = false;
    };

    nix.settings = {
      experimental-features = [ "configurable-impure-env" ];
      impure-env = "GOPROXY=https://goproxy.cn,direct";
    };

    system.stateVersion = "26.05";
  };

  hardware = { ... }: {
    boot.initrd.availableKernelModules = [
      "virtio_pci"
      "virtio_blk"
      "virtio_scsi"
    ];

    boot.kernelParams = [
      "console=ttyS0,115200n8"
      "console=tty0"
    ];

    # reinstall.sh installed GRUB in BIOS mode onto the virtio disk.
    boot.loader.grub = {
      enable = true;
      device = "/dev/vda";
    };

    fileSystems."/" = {
      device = "/dev/disk/by-uuid/bd911ae2-6c13-48cf-86be-7b7526ca8dfc";
      fsType = "ext4";
    };

    swapDevices = [{ device = "/swapfile"; size = 582; }];

    # 2 GiB box: deploys build on the target, zram keeps a closure build alive.
    zramSwap = {
      enable = true;
      memoryPercent = 150;
    };
  };
}
