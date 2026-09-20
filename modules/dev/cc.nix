# As the most basic language in a system even compile the system component
# Use the system support toolchain and tools firstly.
{ lib, config, pkgs, ... }:

with lib;

let cfg = config.modules.dev.cc; in {
  options.modules.dev.cc = {
    enable = mkEnableOption "C/C++ development tools";
  };

  config = mkIf cfg.enable {
    user.packages = with pkgs; [
      clang-tools
    ] ++ (if pkgs.stdenv.hostPlatform.isDarwin then [ ] else [ gcc ]);
  };
}
