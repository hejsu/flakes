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

    services = {
      ssh.enable = true;
      ucasrun.enable = true;
      singbox.enable = true;
    };

    shell = {
      direnv.enable = true;
      git.enable = true;
      fish.enable = true;
      nvim.enable = true;
    };
  };

  settings = { pkgs, ... }: {
    user = {
      initialHashedPassword = "$6$8fKq2Zr9PmLxWvTy$o6W7AAu2IewTITRyufOT8R6i4WqeQxJLs.PZFUEHagBuOdxlAPhktx0OsLj.splluOmMsMmim0cGNjHrabxOW.";
    };

    networking = {
      useNetworkd = true;
      useDHCP = false;
    };

    programs.nix-ld.enable = true;

    # systemd.services.ipv6-ndisc-keepalive = {
    #   description = "IPv6 Gateway NDP Refresh Keepalive";
    #   wants = [ "network-online.target" ];
    #   after = [ "network-online.target" ];
    #   path = [ pkgs.iproute2 pkgs.ndisc6 pkgs.gawk pkgs.iputils ];
    #   script = ''
    #     read -r gw ip < <(ip -6 route get 2001:db8::1 | awk '{for(i=1;i<=NF;i++) {if($i=="via") gw=$(i+1); if($i=="src") ip=$(i+1)}} END {print gw, ip}')
    #     if [ -n "$gw" ] && [ -n "$ip" ]; then
    #       ndisc6 -1 -r 1 -w 250 -q -s "$ip" "$gw" eth0 || true
    #       ping -6 -c 1 -W 1 -I "$ip" 2400:3200::1 >/dev/null 2>&1 || true
    #     fi
    #   '';
    #   serviceConfig = {
    #     Type = "oneshot";
    #   };
    # };

    # systemd.timers.ipv6-ndisc-keepalive = {
    #   wantedBy = [ "timers.target" ];
    #   timerConfig = {
    #     OnBootSec = "10s";
    #     OnUnitActiveSec = "30s";
    #   };
    # };

    systemd.network = {
      enable = true;
      wait-online.enable = false;
    };

    systemd.network.networks."10-eth0" = {
      matchConfig.Name = "eth0";
      networkConfig = {
        DHCP = "yes";
        IPv6PrivacyExtensions = "yes";
      };
    };

    environment.etc."gai.conf".text = ''
      precedence ::ffff:0:0/96 100
    '';

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
