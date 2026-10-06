# C/C++ development tools.
{ lib, config, pkgs, ... }:

with lib;

let cfg = config.modules.dev.cc; in {
  options.modules.dev.cc = {
    enable = mkEnableOption "C/C++ development tools";
  };

  config = mkIf cfg.enable {
    user.packages = with pkgs; [
      clang-tools
      gcc
    ];
  };
}
