{ ... }: {
  imports = [
    ./cliproxyapi.nix
    ./parity.nix
    ./sops.nix
    ./ucasnet
    ./user.nix
    ./zoxide.nix
  ];

  environment.pathsToLink = [ "/Applications" ];
}
