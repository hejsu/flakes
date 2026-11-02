{
  system = "x86_64-linux";

  profiles = {
    user = "suspen";
    role = "server";
    networks = [ "pek" "ts0" ];
  };

  modules = {
    sops = {
      enable = true;
      ageKeyFile = "/var/lib/sops-nix/key.txt";
    };

    shell = {
      fish.enable = true;
      git.enable = true;
    };

    services = {
      ssh.enable = true;
    };
  };

  ## Local config
  settings = { lib, pkgs, ... }: {
    system.stateVersion = "26.05";

    networking = {
      usePredictableInterfaceNames = false;
      useNetworkd = true;
      useDHCP = false;
    };

    systemd.network.networks."10-eth0" = {
      matchConfig.Name = "eth0";
      networkConfig = {
        DHCP = "ipv4";
        IPv6AcceptRA = true;
        DNS = [
          "223.5.5.5"
          "119.29.29.29"
        ];
      };
      dhcpV4Config.UseDNS = false;
    };

    services.tailscale.derper = {
      enable = true;
      domain = "hws.blenny-ayu.ts.net";
      configureNginx = false;
      port = 33443;
      stunPort = 3478;
      openFirewall = true;
      verifyClients = true;
    };

    networking.firewall.allowedTCPPorts = [ 33443 ];

    systemd.services.tailscale-derper = {
      after = [ "tailscaled.service" ];
      wants = [ "tailscaled.service" ];

      serviceConfig.ExecStart = lib.mkForce (lib.concatStringsSep " " [
        "${pkgs.tailscale.derper}/bin/derper"
        "-a=:33443"
        "-hostname=hws.blenny-ayu.ts.net"
        "-certmode=manual"
        "-certdir=/var/lib/derper/certs-sni"
        "-c=/var/lib/derper/derper.key"
        "-http-port=-1"
        "-stun-port=3478"
        "-verify-clients"
      ]);
    };
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
