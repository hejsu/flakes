# Typst: A typesetting software simpler than Latex.
{ lib, config, pkgs, ... }:

let cfg = config.modules.dev.typst; in {
  options.modules.dev.typst = {
    enable = lib.mkEnableOption "Typst typesetting";
  };

  config = lib.mkIf cfg.enable {
    user.packages = with pkgs; [
      typst
      # tinymist
    ];
  };
}

