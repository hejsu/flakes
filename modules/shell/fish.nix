{ self, lib, config, pkgs, ... }:

let cfg = config.modules.shell.fish; in {
  options.modules.shell.fish = with lib; with types; {
    enable = mkEnableOption "Fish shell";

    shellInit = mkOption {
      type = lines;
      default = "";
      description = "Fish script to run in all sessions (environment & paths).";
    };

    loginInit = mkOption {
      type = lines;
      default = "";
      description = "Fish script to run only when (status is-login).";
    };

    interactiveInit = mkOption {
      type = lines;
      default = "";
      description = "Fish script to run only when (status is-interactive).";
    };

    interactiveFiles = mkOption {
      type = listOf (either str path);
      default = [ ];
      description = "External fish files to source only when (status is-interactive).";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.shells = [ pkgs.fish ];
    users.defaultUserShell = pkgs.fish;

    home.sessionVariables = {
      NH_FLAKE = config.home.flakeDir;
    };

    programs.fish.enable = true;

    home.configFile = {
      "fish/config.fish".text = ''
        # 1. Base Environment & Paths (Always loaded)
        source "${config.hjem.users.${config.user.name}.environment.loadEnv}"
        ${lib.concatMapStringsSep "\n" (p: "fish_add_path -m '${p}'") config.home.sessionPath}

        # modules.shell.fish.shellInit
        ${cfg.shellInit}

        # 2. Login Session Hooks (status is-login)
        if status is-login
          ${cfg.loginInit}
        end

        # 3. Interactive Session Setup (status is-interactive)
        if status is-interactive
          # modules.shell.fish.interactiveInit
          ${cfg.interactiveInit}

          # modules.shell.fish.interactiveFiles
          ${lib.concatMapStringsSep "\n" (f: "test -r '${toString f}'; and source '${toString f}'") cfg.interactiveFiles}
        end
      '';

      "fish/conf.d".source = "${self.configDir}/fish/conf.d";
      "fish/functions".source = "${self.configDir}/fish/functions";
      "fish/completions".source = "${self.configDir}/fish/completions";
      "fish/themes".source = "${self.configDir}/fish/themes";

      "yazi".source = "${self.configDir}/yazi";
    };

    environment.shellAliases.yz = "yazi";

    programs.zoxide = {
      enable = true;
      excludeDirs = [
        "/tmp"
        "/var"
        "/proc"
        "/sys"
        "node_modules"
        "dist"
        "build"
      ];
    };

    user.packages = with pkgs; [
      # CLI core & tools
      kitty.terminfo
      coreutils
      fzf
      yazi
      ripgrep
      tree
      less
      htop
      unzip
      bat
      tlrc
      wget
      curl
      tokei
      fastfetch
      nh
    ];
  };
}
