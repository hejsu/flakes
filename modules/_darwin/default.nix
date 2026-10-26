{ ... }: {
  imports = [
    ./cliproxyapi.nix
    ./parity.nix
    ./sops.nix
    ./ucas-ipv6-fix
    ./user.nix
    ./zoxide.nix
  ];

  environment.pathsToLink = [ "/Applications" ];
}
