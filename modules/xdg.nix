{ lib, config, ... }:

let cfg = config.modules.xdg; in {
  options.modules.xdg = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enforce XDG base directories for common programs.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.variables = {
      # Shells
      ZDOTDIR = "${config.home.configDir}/zsh";
      HISTFILE = "${config.home.stateDir}/bash/history";
      INPUTRC = "${config.home.configDir}/readline/inputrc";
      LESSHISTFILE = "${config.home.stateDir}/less/history";

      # Node / NPM
      NPM_CONFIG_USERCONFIG = "${config.home.configDir}/npm/npmrc";
      NPM_CONFIG_CACHE = "${config.home.cacheDir}/npm";
      NODE_REPL_HISTORY = "${config.home.dataDir}/node/repl_history";

      # GitHub Copilot (still used by VS Code)
      COPILOT_HOME = "${config.home.configDir}/copilot";

      # Toolchains / Dev
      DOCKER_CONFIG = "${config.home.configDir}/docker";
      GNUPGHOME = "${config.home.dataDir}/gnupg";

      # Databases & CLI Tools
      SQLITE_HISTORY = "${config.home.stateDir}/sqlite_history";
      WGETRC = "${config.home.configDir}/wgetrc";
    };

    # macOS /etc/zshrc hardcodes HISTFILE to ~/.zsh_history; override it here.
    home.configFile."zsh/.zshrc".text = ''
      HISTFILE="${config.home.stateDir}/zsh/history"
      mkdir -p "${config.home.stateDir}/zsh"
    '';

    home.configFile."wgetrc".text = ''
      hsts-file = ${config.home.cacheDir}/wget-hsts
    '';
  };
}
