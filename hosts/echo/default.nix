{
  system = "x86_64-linux";

  includes = [
    ./backup.nix
    ./ddns.nix
    ./lan.nix
    ./singbox.nix
  ];

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
        ingress.tailnet.cpa.endpoints.
          "tcp:80" = "tcp://127.0.0.1:8315";
      };

      magpie = {
        enable = true;
        ingress.tailnet.magpie.endpoints.
          "tcp:80" = "tcp://127.0.0.1:3430";
        ingress.tailnet.magpie-api.endpoints.
          "tcp:80" = "tcp://127.0.0.1:3425";
      };
    };
  };

  settings = { ... }: {
    programs.nix-ld.enable = true;

    ## Magpie Podman Auto Update
    systemd.timers.podman-auto-update = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = [ "" "*-*-* 03:00:00" ];
      };
    };
    virtualisation.oci-containers.containers = {
      magpie.labels."io.containers.autoupdate" = "registry";
    };

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

    networking.getaddrinfo.precedence."::ffff:0:0/96" = 100;

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
