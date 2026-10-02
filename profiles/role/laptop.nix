{ pkgs, config, ... }: {
  # ONLY DARWIN
  assertions = [{
    assertion = pkgs.stdenv.hostPlatform.isDarwin;
    message = "The 'laptop' profile is currently configured exclusively for macOS!";
  }];

  # font
  fonts.packages = with pkgs; [
    fira
    fira-code
    nerd-fonts.fira-code
    nerd-fonts.symbols-only
    julia-mono
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
  ];

  # Determinate Nix 
  nix.enable = false;

  environment.etc."nix/nix.custom.conf".text = ''
    warn-dirty = false
    use-xdg-base-directories = true
    trusted-users = ${config.user.name} root
    substituters = https://mirrors.ustc.edu.cn/nix-channels/store https://cache.nixos.org
    http-connections = 50
    max-substitution-jobs = 32
  '';

  # macOS 
  # Host & User identity
  system.primaryUser = config.user.name;

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

  homebrew = {
    enable = true;
    enableFishIntegration = true;
    onActivation.cleanup = "zap";

    onActivation.extraEnv = {
      XDG_CONFIG_HOME = "${config.home.configDir}";
      HOMEBREW_API_DOMAIN = "https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api";
      HOMEBREW_BREW_GIT_REMOTE = "https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git";
      HOMEBREW_CORE_GIT_REMOTE = "https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git";
      HOMEBREW_PIP_INDEX_URL = "https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple";
    };
  };
}
