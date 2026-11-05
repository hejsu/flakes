{ self, lib, config, ... }:

let cfg = config.modules.apps.emacs; in {
  options.modules.apps.emacs.enable =
    lib.mkEnableOption "Emacs, installed from the emacs-plus cask";

  config = lib.mkIf cfg.enable {
    homebrew.taps = [ "d12frosted/emacs-plus" ];
    homebrew.casks = [ "emacs-plus-app" ];

    home.configFile = {
      "emacs/early-init.el".source = "${self.configDir}/emacs/early-init.el";
      "emacs/init.el".source = "${self.configDir}/emacs/init.el";
      "emacs/cfg".source = "${self.configDir}/emacs/cfg";
      "emacs/straight-versions.el".source = "${self.configDir}/emacs/straight-versions.el";
    };
  };
}
