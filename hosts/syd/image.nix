# Build-only disk layout and image-specific first-boot initialization.
# Registered via image.modules.vhdx; never imported by the daily host.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/image/repart.nix") ];

  image.repart = {
    enable = true;
    name = "syd";
    version = null;
    imageSize = "10G";
    compression.enable = false;

    partitions = {
      "10-esp" = {
        repartConfig = {
          Type = "esp";
          Format = "vfat";
          Label = "SYD-ESP";
          SizeMinBytes = "1G";
          SizeMaxBytes = "1G";
        };

        contents = {
          "/EFI/BOOT/BOOTX64.EFI".source =
            "${config.systemd.package}/lib/systemd/boot/efi/systemd-bootx64.efi";
          "/EFI/systemd/systemd-bootx64.efi".source =
            "${config.systemd.package}/lib/systemd/boot/efi/systemd-bootx64.efi";
          "/EFI/Linux/syd.efi".source =
            "${config.system.build.uki}/${config.system.boot.loader.ukiFile}";
        };
      };

      "20-system" = {
        storePaths = [ config.system.build.toplevel ];
        nixStorePrefix = "/nix/store";
        contents."/root/nix-path-registration".source =
          "${pkgs.closureInfo {
            rootPaths = [ config.system.build.toplevel ];
          }}/registration";

        repartConfig = {
          Type = "root";
          Format = "btrfs";
          Label = "syd";
          Subvolumes = "/root /home /nix";
          DefaultSubvolume = "/root";
          MakeDirectories = "/root /home /nix /root/boot /root/home /root/nix";
          Compression = "zstd";
        };
      };
    };
  };

  # The store/profile initialization follows nixpkgs' sd-image.nix. Use runtime
  # paths here: referencing this system's toplevel would create a closure cycle.
  systemd.services.register-nix-paths = {
    description = "Initialize the syd image's Nix store and boot generations";
    enableStrictShellChecks = true;
    unitConfig = {
      DefaultDependencies = false;
      ConditionPathExists = "/nix-path-registration";
      RequiresMountsFor = [ "/nix" "/boot" ];
    };
    wantedBy = [ "sysinit.target" ];
    after = [
      "local-fs.target"
      "systemd-tmpfiles-setup.service"
      "systemd-machine-id-commit.service"
    ];
    requires = [ "systemd-tmpfiles-setup.service" ];
    before = [
      "sysinit.target"
      "nix-daemon.socket"
      "nix-daemon.service"
      "nix-gc.service"
      "nix-optimise.service"
      "shutdown.target"
    ];
    conflicts = [ "shutdown.target" ];
    restartIfChanged = false;
    environment = {
      HOME = "/root";
      NIX_REMOTE = "local";
    };
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -euo pipefail
      system="$(${lib.getExe' pkgs.coreutils "readlink"} -f /run/current-system)"
      ${lib.getExe' config.nix.package.out "nix-store"} --load-db < /nix-path-registration
      ${lib.getExe' pkgs.coreutils "touch"} /etc/NIXOS
      ${lib.getExe' config.nix.package.out "nix-env"} \
        -p /nix/var/nix/profiles/system --set "$system"

      # Install normal generation entries and their default using NixOS' builder.
      NIXOS_INSTALL_BOOTLOADER=1 ${config.system.build.installBootLoader} "$system"

      # Do not remove the initial UKI or retry marker on an earlier failure.
      ${lib.getExe' pkgs.coreutils "rm"} -f /boot/EFI/Linux/syd.efi
      ${lib.getExe' pkgs.coreutils "sync"} -f /boot
      ${lib.getExe' pkgs.coreutils "rm"} -f /nix-path-registration
      ${lib.getExe' pkgs.coreutils "sync"} -f /
    '';
  };

  # Ordering alone does not stop these units after a registration failure.
  # Requires + After (above) prevents them from using/GCing an unregistered store.
  systemd.sockets.nix-daemon.requires = [ "register-nix-paths.service" ];
  systemd.services.nix-daemon.requires = [ "register-nix-paths.service" ];
  systemd.services.nix-gc.requires = [ "register-nix-paths.service" ];
  systemd.services.nix-optimise.requires = [ "register-nix-paths.service" ];

  image.extension = lib.mkForce "vhdx";
  system.build.image = lib.mkForce (config.image.repart.image.overrideAttrs (old: {
    nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.qemu-utils pkgs.jq ];
    postBuild = (old.postBuild or "") + ''
      raw_size="$(stat -c %s "${config.image.baseName}.raw")"
      qemu-img convert -f raw -O vhdx -o subformat=dynamic \
        "${config.image.baseName}.raw" "${config.image.fileName}"
      qemu-img info --output=json "${config.image.fileName}" \
        | jq -e --argjson size "$raw_size" '.format == "vhdx" and .["virtual-size"] == $size'
      rm "${config.image.baseName}.raw"
    '';
  }));
}
