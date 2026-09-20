{ ss, ... }: {
  system = "aarch64-darwin";

  profiles = {
    user = "suspen";
    role = "laptop";
  };

  includes = [
    ss.modules.adhoc.kitty
    ss.modules.adhoc.zed
  ];

  modules = {
    xdg.enable = true;

    shell = {
      fish.enable = true;
      git.enable  = true;
      nvim.enable = true;
      yazi.enable = true;
    };

    sops = {
      enable = true;
      secrets.hello = {
        owner = "suspen";
        group = "staff";
      };
    };

    dev = {
      cc.enable     = true;
      typst.enable  = true;
      python.enable = true;
    };

    apps = {
      kitty.enable = true;
      zed.enable   = true;
    };

    services = {
      cliproxyapi.enable = true;
    };
  };

  # 4. Setting (Machine-specific Native Overrides & Patches)
  settings = { lib, config, ... }: {
    home.sessionVariables = {
      # secretive
      SSH_AUTH_SOCK = "${config.home.dir}/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh";

      # code cli
      VSCODE_CLI_DATA_DIR = "${config.home.dir}/Applications/vscode/code-portable-data/cli-data";
    };

    launchd.user.envVariables = {
      GEMINI_CLI_HOME = "${config.home.configDir}/gemini";
      COPILOT_HOME    = "${config.home.configDir}/copilot";
      CODEX_HOME      = "${config.home.configDir}/codex";
    };

    # Host & User identity
    system.primaryUser = config.user.name;

    # macOS System preferences
    system.stateVersion = 6;
    security.pam.services.sudo_local.touchIdAuth = true;

    system.defaults = {
      dock.autohide = true;
      dock.mru-spaces = false;
      finder.AppleShowAllExtensions = true;
      finder.FXPreferredViewStyle = "clmv";
      loginwindow.GuestEnabled = false;
      NSGlobalDomain = {
        ApplePressAndHoldEnabled = false;
        AppleICUForce24HourTime = true;
        AppleInterfaceStyle = "Dark";
        KeyRepeat = 2;
      };
    };

    # Nix configuration (Determinate Systems daemon)
    nix.enable = false;

    environment.etc."nix/nix.custom.conf".text = ''
      warn-dirty = false
      use-xdg-base-directories = true
      trusted-users = ${config.user.name} root
      builders-use-substitutes = true
      substituters = https://mirrors.ustc.edu.cn/nix-channels/store https://cache.nixos.org
      http-connections = 50
      max-substitution-jobs = 32
      eval-cores = 0
    '';

    launchd.daemons.nix-gc = {
      command = "/nix/var/nix/profiles/default/bin/nix-collect-garbage --delete-older-than 4d";
      serviceConfig.RunAtLoad = false;
      serviceConfig.StartCalendarInterval = [{ Weekday = 7; Hour = 3; Minute = 15; }];
    };

    environment.profiles = lib.mkForce [
      "/nix/var/nix/profiles/default"
      "/run/current-system/sw"
      "/etc/profiles/per-user/${config.user.name}"
    ];

    # Darwin-specific shell optimizations
    programs.fish.useBabelfish = true;

    # Homebrew configuration
    homebrew = {
      enable = true;
      enableFishIntegration = true;
      onActivation.cleanup  = "zap";

      onActivation.extraEnv = {
        XDG_CONFIG_HOME          = "${config.home.configDir}";
        HOMEBREW_API_DOMAIN      = "https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api";
        HOMEBREW_BREW_GIT_REMOTE = "https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git";
        HOMEBREW_CORE_GIT_REMOTE = "https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git";
        HOMEBREW_PIP_INDEX_URL   = "https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple";
      };

      brews = [
        "docker"
        "docker-compose"
        "gcc"
        "pi-coding-agent"
      ];

      casks = [
        "wechat"
        "qq"
        "google-chrome"
        "zotero"
        "tencent-meeting"
        "feishu"
        "visual-studio-code"

        "the-unarchiver"
        "keka"

        "appcleaner"
        "tailscale-app"
        "secretive"

        "coteditor"
      ];
    };
  };
}
