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

      # WORKAROUND: https://github.com/nix-community/nix-direnv/issues/786
      direnvrcExtra = ''
        _nix_refresh_gcroots() { :; }
      '';
    };
  };
}

