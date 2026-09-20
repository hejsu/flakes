{ lib, config, pkgs, ... }:

let cfg = config.modules.dev.python; in {
  options.modules.dev.python = {
    enable = lib.mkEnableOption "Python development environment";
  };

  config = lib.mkIf cfg.enable {
    user.packages = with pkgs; [
      python313
      uv
    ];

    home.sessionPath = [ "${config.home.dataDir}/python/bin" ];

    environment.variables = {
      PYTHONUSERBASE = "${config.home.dataDir}/python";
      PYTHON_HISTORY = "${config.home.dataDir}/python/python_history";
      PYTHONPYCACHEPREFIX = "${config.home.cacheDir}/python";
    };
  };
}
