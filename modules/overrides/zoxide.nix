{ lib, config, ... }:

with lib;
let cfg = config.programs.zoxide; in {
  options.programs.zoxide = {
    excludeDirs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "List of directory globs to be excluded from zoxide database.";
    };
  };

  config = mkIf (cfg.enable && cfg.excludeDirs != [ ]) {
    environment.variables = {
      _ZO_EXCLUDE_DIRS = concatStringsSep ":" cfg.excludeDirs;
    };
  };
}

