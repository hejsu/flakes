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
      direnvrcExtra = ''
        _nix_refresh_gcroots() { :; }
      '';
    };

    nix.settings = {
      keep-outputs = true;
      keep-derivations = true;
    };
  };
}

