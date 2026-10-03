{ lib, config, pkgs, ... }:

with lib;

let cfg = config.modules.dev.nix; in {
  options.modules.dev.nix = {
    enable = mkEnableOption "Nix language tooling";
  };

  config = mkIf cfg.enable {
    user.packages = with pkgs; [
      nixd
      nil
    ];
  };
}
