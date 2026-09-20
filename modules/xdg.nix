{ lib, config, ... }:

let
  cfg = config.modules.xdg;
in {
  options.modules.xdg = {
    enable = lib.mkEnableOption "XDG environment variables and configuration";
  };

  config = lib.mkIf cfg.enable {
    environment.variables = {
      # Shells
      ZDOTDIR      = "${config.home.configDir}/zsh";
      HISTFILE     = "${config.home.stateDir}/bash/history";
      INPUTRC      = "${config.home.configDir}/readline/inputrc";
      LESSHISTFILE = "${config.home.stateDir}/less/history";

      # Node / NPM
      NPM_CONFIG_USERCONFIG = "${config.home.configDir}/npm/npmrc";
      NPM_CONFIG_CACHE      = "${config.home.cacheDir}/npm";
      NODE_REPL_HISTORY     = "${config.home.dataDir}/node/repl_history";

      # Pi Coding Agent
      PI_CODING_AGENT_DIR         = "${config.home.configDir}/pi/agent";
      PI_CODING_AGENT_SESSION_DIR = "${config.home.dataDir}/pi/sessions";

      CODEX_HOME      = "${config.home.configDir}/codex";
      GEMINI_CLI_HOME = "${config.home.configDir}/gemini";
      COPILOT_HOME    = "${config.home.configDir}/copilot";

      # Toolchains / Dev
      DOCKER_CONFIG = "${config.home.configDir}/docker";
      GNUPGHOME     = "${config.home.dataDir}/gnupg";

      # Databases & CLI Tools
      SQLITE_HISTORY = "${config.home.stateDir}/sqlite_history";
      WGETRC         = "${config.home.configDir}/wgetrc";
    };

    home.configFile."wgetrc".text = ''
      hsts-file = ${config.home.cacheDir}/wget-hsts
    '';
  };
}
