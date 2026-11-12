{ ... }: {
  # Keep platform selection here, not scattered through shared modules.
  # Darwin's external Nix and launchd maintenance are configured in role/laptop.
  disabledModules = [
    ../preset.nix
    ../security.nix
    ../networking/ssh.nix
    ../networking/singbox.nix
    ../services/cliproxyapi.nix
    ../services/magpie.nix
  ];

  imports = [
    ./apps
    ./parity.nix
    ./sops.nix
    ./user.nix
    ./zoxide.nix
  ];

  environment.pathsToLink = [ "/Applications" ];
}
