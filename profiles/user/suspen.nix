{ pkgs, ... }: {
  user.name = "suspen";

  home.impure.enable = true;

  time.timeZone = "Asia/Shanghai";

  user.packages = with pkgs; [
    # Nix language tooling
    nixd
    nil

    # Development & host utilities
    cliproxyapi
    dash
    sops
    age

    opencode
  ];
}


