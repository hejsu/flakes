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
    sops.templates."cloudflare-acme-env" = {
      owner = "acme";
      group = "acme";
      mode = "0400";
      content = ''
        CF_DNS_API_TOKEN="${config.sops.placeholder."cloudflare-api-token-dns-edit-zone-read"}"
      '';
    };

    security.acme = {
      acceptTerms = true;
      defaults.email = "suspen@outlook.sk";
    };

    security.acme.certs."derp.aoran.eu.org" = {
      dnsProvider = "cloudflare";
      environmentFile = config.sops.templates."cloudflare-acme-env".path;
      group = "caddy";
      reloadServices = [ "caddy.service" ];

      # https://github.com/go-acme/lego/discussions/3261
      extraLegoFlags = [ "--dns.propagation.disable-rns" ];
    };

    services.caddy.enable = true;

    services.caddy.virtualHosts."https://derp.aoran.eu.org:33443".extraConfig = ''
      tls /var/lib/acme/derp.aoran.eu.org/fullchain.pem \
          /var/lib/acme/derp.aoran.eu.org/key.pem
      reverse_proxy 127.0.0.1:8081
    '';

    systemd.services.caddy.after = [ "acme-derp.aoran.eu.org.service" ];
    systemd.services.caddy.wants = [ "acme-derp.aoran.eu.org.service" ];

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
