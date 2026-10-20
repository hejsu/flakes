{ ... }: {
  imports = [
    ./cliproxyapi.nix
    ./parity.nix
    ./sops.nix
    ./ucasnet.nix
    ./user.nix
    ./zoxide.nix
  ];

  environment.pathsToLink = [ "/Applications" ];
}
