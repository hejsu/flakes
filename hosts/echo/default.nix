{
  system = "x86_64-linux";

  profiles = {
    user = "suspen";
    role = "server";
    networks = [ "pek" "ts0" "ucas" ];
  };

  modules = {
    sops.enable = true;

    shell = {
      direnv.enable = true;
      git.enable = true;
      fish.enable = true;
      nvim.enable = true;
      comma.enable = true;
    };

    networking = {
      ssh.enable = true;
      singbox.enable = true;
    };

    services = {
      cliproxyapi = {
        enable = true;
        ingress.tailnet = {
          cpa.endpoints."tcp:80" = "tcp://127.0.0.1:8315";
        };
      };

      magpie = {
        enable = true;
        ingress.tailnet = {
          magpie.endpoints."tcp:80" = "tcp://127.0.0.1:3430";
          magpie-api.endpoints."tcp:80" = "tcp://127.0.0.1:3425";
        };
      };
    };
  };

  settings = { config, lib, pkgs, ... }: {
    programs.nix-ld.enable = true;

    ## Magpie Podman Auto Update
    systemd.timers.podman-auto-update = lib.mkIf config.modules.services.magpie.enable {
      wantedBy = [ "timers.target" ];
    };
    virtualisation.oci-containers.containers = lib.mkIf config.modules.services.magpie.enable {
      magpie.labels."io.containers.autoupdate" = "registry";
    };

    # workaround on singbox tun and podman: https://github.com/SagerNet/sing-box/issues/2700
    # But it's not necessary when using host networking
    # networking.firewall.trustedInterfaces = [ "podman0" ];

    systemd.network.networks."10-eth0" = {
      matchConfig.Name = "eth0";

      networkConfig = {
        DHCP = "ipv4";
        IPv6AcceptRA = true;
        IPv6PrivacyExtensions = false;
        DNS = [
          "210.77.16.1"
          "119.29.29.29"
        ];
      };

      dhcpV4Config.UseDNS = false;

      ipv6AcceptRAConfig = {
        # ucas ipv6 fix
        RouterAllowList = [ "fe80::7625:8aff:fe00:f1ab" ];
      };
    };

    environment.etc."gai.conf".text = ''
      precedence ::ffff:0:0/96 100
    '';

    sops.secrets = {
      "restic-password" = { };
      "s3-cstnet-ak" = { };
      "s3-cstnet-sk" = { };
    };

    sops.templates."restic.env" = {
      mode = "0400";
      content = ''
        AWS_ACCESS_KEY_ID="${config.sops.placeholder."s3-cstnet-ak"}"
        AWS_SECRET_ACCESS_KEY="${config.sops.placeholder."s3-cstnet-sk"}"
      '';
    };

    services.restic.backups.cpa = {
      initialize = true;
      repository = "s3:https://s3.cstcloud.cn/echo-restic";
      environmentFile = config.sops.templates."restic.env".path;
      passwordFile = config.sops.secrets."restic-password".path;
      extraOptions = [ "s3.bucket-lookup=path" ];

      paths = [
        "/var/lib/private/cliproxyapi"
        "/var/lib/private/cpa-usage-keeper"
      ];

      exclude = [
        "/var/lib/private/cliproxyapi/auth/logs"
        "/var/lib/private/cpa-usage-keeper/logs"
      ];

      pruneOpts = [ "--keep-daily 30" "--keep-weekly 12" "--keep-monthly 12" ];
      runCheck = true;
      checkOpts = [ "--read-data" ];
    };

    sops.secrets."cloudflare-api-token-dns-edit-zone-read" = { };

    sops.templates."cloudflare-ddns-env" = {
      restartUnits = [ "cloudflare-ddns.service" ];
      owner = "cloudflare-ddns";
      group = "cloudflare-ddns";
      mode = "0440";
      content = ''
        CLOUDFLARE_API_TOKEN="${config.sops.placeholder."cloudflare-api-token-dns-edit-zone-read"}"
      '';
    };

    services.cloudflare-ddns = {
      enable = true;
      credentialsFile = config.sops.templates."cloudflare-ddns-env".path;

      ip6Domains = [ "echo.aoran.eu.org" ];
      provider.ipv4 = "none";
      provider.ipv6 = "local.iface:eth0";

      ttl = 60;
      proxied = "false";
      updateCron = "@every 5m";
    };

    systemd.services.cloudflare-ddns.serviceConfig = {
      ProtectSystem = "strict";
      ReadWritePaths = [ "/var/lib/cloudflare-ddns" ];
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
    };

    system.stateVersion = "26.11";
  };

  hardware = { ... }: {
    virtualisation.hypervGuest.enable = true;

    boot.tmp.useTmpfs = true;
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
