{ ... }: {
  imports = [
    ./cliproxyapi.nix
    ./parity.nix
    ./sops.nix
    ./user.nix
    ./zoxide.nix
  ];

  environment.pathsToLink = [ "/Applications" ];
}
