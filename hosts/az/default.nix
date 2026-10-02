# az — Azure VM (bootstrapped via nixos-infect), x86_64-linux
{
  system = "x86_64-linux";

  profiles = {
    user = "suspen";
    role = "server";
  };

  modules = { };

  ## Local config
  settings = { lib, ... }: with lib; {
    # Enable nix flakes permanently (nixos-infect ships without them).
    nix.settings.experimental-features = [ "nix-command" "flakes" ];

    # Workaround for https://github.com/NixOS/nix/issues/8502
    # (logrotate checkConfig fails when /var/log/journal doesn't exist yet)
    services.logrotate.checkConfig = false;

    networking.domain = "t0tivnfifftexijyidewzlguwg.lx.internal.cloudapp.net";

    boot = {
      tmp.cleanOnBoot = true;
      kernelParams = [ "console=tty1" "console=ttyS0,115200" ];
    };

    services.openssh.enable = true;

    users.users.root.openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDKUwL8ZKZSewososw99ZQpR9IAEXjiwKeFtPom3Iu6EbrSiqGXbHWUZVTHOaUMd5GCvlBjwsJL1L8NlGp47DIyrsd8CP1I/1tN+r7zTJVpEUnaxwlaoFpCpxPiDewBibCLmmHwoosTRqqeURJvQiwwerGowJNoL1HEbbJvrBiz2AhsDxaBG/cb0aZ7DnOtgLJQqt0edTFWgLVECB/k2XIHmVhjZ54MSJPfYbfgFzykTWigrv3WrATnwe/LbB2Yiq2M4NbLxzJG+fFWhWZmWMffB/jRnSjmYgMEhjnbI3Nr9I2Om8+zo8AMaqiTzeSRgK9bapQqfG6nIfJ+PR2fz5xi5AX7DPpYdI6W6oOSBItc32fTJSJ8SV578A0hMgo/UmJ6NaVnvbf6AAe4TYNnTjgaX/XPcOHZ5TCOGqG7dhJFTTxXiT8gQYBMswl3vj6IpgIL1gqd3Ztydlwne1VOSI/ZhVZRYw5YAD3ws7DR+Wk4/5aNcqb06PFHDhR+yv6b7kk= generated-by-azure"
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBNhZOawFtfii6oSbLM/q8KMfl8u2K9e6R2F8JeeKuIvmJnS8i7BlzocvN8/p3bE/rL6Z+9wi12rWZJCG/Ge6l+Y= main-key@secretive.shu.local"
    ];

    system.stateVersion = "23.11";
  };

  hardware = { ... }: {
    virtualisation.hypervGuest.enable = true;

    boot = {
      loader = {
        efi.efiSysMountPoint = "/boot/efi";
        grub = {
          efiSupport = true;
          efiInstallAsRemovable = true;
          device = "nodev";
        };
      };
    };

    fileSystems = {
      "/boot/efi" = {
        device = "/dev/disk/by-uuid/F086-A453";
        fsType = "vfat";
      };

      "/" = {
        device = "/dev/sda1";
        fsType = "ext4";
      };
    };

    zramSwap.enable = true;
    swapDevices = [
      {
        device = "/swapfile";
        size = 8192; # MiB
      }
    ];
  };
}
