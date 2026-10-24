{ lib, config, ... }:

let cfg = config.modules.shell.direnv; in {
  options.modules.shell.direnv = {
    enable = lib.mkEnableOption "Direnv integration with nix-direnv";
  };

  config = lib.mkIf cfg.enable {
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
      silent = true;

      # Workaround for nix-community/nix-direnv#786
      # REVIEW: Remove when pkgs.direnv gets beyond 3.2.0
      direnvrcExtra = ''
        _nix_refresh_gcroots() { :; }
      '';
    };
  };
}

