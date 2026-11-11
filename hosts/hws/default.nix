{
  system = "x86_64-linux";

  profiles = {
    user = "suspen";
    role = "server";
    networks = [ "pek" "ts0" ];
  };

  modules = {
    sops.enable = true;

    shell = {
      fish.enable = true;
      git.enable = true;
    };

    networking = {
      ssh.enable = true;
    };
  };

  ## Local config
  settings = { lib, pkgs, config, ... }: {

    systemd.network.networks."99-wired" = {
      networkConfig.DNS = [
        "223.5.5.5"
        "119.29.29.29"
      ];
      dhcpV4Config.UseDNS = false;
    };

    sops.secrets."cloudflare-api-token-dns-edit-zone-read" = { };
    sops.templates."caddy-cloudflare-env" = {
      restartUnits = [ "caddy.service" ];
      owner = "caddy";
      group = "caddy";
      content = ''
        CF_API_TOKEN="${config.sops.placeholder."cloudflare-api-token-dns-edit-zone-read"}"
      '';
    };

    nix.settings = {
      experimental-features = [ "configurable-impure-env" ];
      impure-env = "GOPROXY=https://goproxy.cn,direct";
    };

    services.caddy = {
      enable = true;
      email = "suspen@outlook.sk";
      environmentFile = config.sops.templates."caddy-cloudflare-env".path;
      package = pkgs.caddy.withPlugins {
        plugins = [ "github.com/caddy-dns/cloudflare@v0.2.4" ];
        hash = "sha256-QSiwKqKvSxhksWBF4/MlBOpyXba5xOQ2sRwA0R7399E=";
      };
    };

    services.caddy.virtualHosts."https://derp.aoran.eu.org:33443".extraConfig = ''
      tls {
        dns cloudflare {env.CF_API_TOKEN}
      }
      reverse_proxy 127.0.0.1:8081
    '';

    services.tailscale.derper = {
      enable = true;
      domain = "derp.aoran.eu.org";
      configureNginx = false;
      port = 8081;
      stunPort = 3478;
      openFirewall = true;
      verifyClients = true;
    };

    networking.firewall.allowedTCPPorts = [ 33443 ];

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
