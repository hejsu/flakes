{ ss, lib, config, options, ... }:

with lib;
let cfg = config.home; in {
  imports = [
    ss.modules.hjem.default
  ];

  options.home = with types; {
    file = mkOption { type = attrs; default = { }; description = "Files to place directly in $HOME"; };
    configFile = mkOption { type = attrs; default = { }; description = "Files to place in $XDG_CONFIG_HOME"; };
    dataFile = mkOption { type = attrs; default = { }; description = "Files to place in $XDG_DATA_HOME"; };

    sessionPath = mkOption { type = listOf (either str path); default = [ ]; description = "Extra directories in PATH"; };
    sessionVariables = mkOption { type = attrs; default = { }; description = "Environment variables to set in the user session."; };

    dir = mkOption { type = str; default = config.users.users.${config.user.name}.home; };
    binDir = mkOption { type = str; default = "${cfg.dir}/.local/bin"; };
    cacheDir = mkOption { type = str; default = "${cfg.dir}/.cache"; };
    configDir = mkOption { type = str; default = "${cfg.dir}/.config"; };
    dataDir = mkOption { type = str; default = "${cfg.dir}/.local/share"; };
    stateDir = mkOption { type = str; default = "${cfg.dir}/.local/state"; };

    flakeDir = mkOption { type = str; default = "${cfg.dir}/.config/dotfiles"; };
  };

  config = {
    # System-level XDG environment variables
    environment.variables = {
      XDG_BIN_HOME = cfg.binDir;
      XDG_CACHE_HOME = cfg.cacheDir;
      XDG_CONFIG_HOME = cfg.configDir;
      XDG_DATA_HOME = cfg.dataDir;
      XDG_STATE_HOME = cfg.stateDir;
    };

    home.sessionPath = [ "${cfg.binDir}" ];

    hjem = {
      clobberByDefault = true;
      users.${config.user.name} = {
        enable = true;
        files = mkAliasDefinitions options.home.file;

        xdg = {
          config.files = mkAliasDefinitions options.home.configFile;
          data.files = mkAliasDefinitions options.home.dataFile;

          # Force these, since it'll be considered an abstraction leak to use
          # Hjem's API anywhere outside this module.
          cache.directory = mkForce cfg.cacheDir;
          config.directory = mkForce cfg.configDir;
          data.directory = mkForce cfg.dataDir;
          state.directory = mkForce cfg.stateDir;
        };

        environment.sessionVariables = mkAliasDefinitions options.home.sessionVariables;
      };
    };
  };
}
