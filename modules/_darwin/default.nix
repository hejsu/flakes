{ ... }: {
  # Keep platform selection here, not scattered through shared modules.
  # Darwin's external Nix and launchd maintenance are configured in role/laptop.
  disabledModules = [
    ../preset.nix
    ../security.nix
    ../services/caddy.nix
    ../services/openssh.nix
    ../services/sing-box.nix
  ];

  imports = [
    ./apps
    ./parity.nix
    ./sops.nix
    ./syncthing.nix
    ./user.nix
    ./zoxide.nix
  ];

  environment.pathsToLink = [ "/Applications" ];
}
