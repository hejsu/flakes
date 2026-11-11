{ pkgs, config, lib, ... }: {
  # ONLY DARWIN
  assertions = [{
    assertion = pkgs.stdenv.hostPlatform.isDarwin;
    message = "The 'laptop' profile is currently configured exclusively for macOS!";
  }];

  # Weekly maintenance. Determinate Nixd already collects the store, so this
  # only trims system generations and dedupes the store.
  launchd.daemons.nix-gc = {
    script = ''
      /nix/var/nix/profiles/default/bin/nix-env \
        --profile /nix/var/nix/profiles/system \
        --delete-generations 7d
      /nix/var/nix/profiles/default/bin/nix store optimise
    '';
    serviceConfig = {
      StartCalendarInterval = [ { Weekday = 0; Hour = 4; } ];
      RunAtLoad = false;
      StandardOutPath = "/var/log/nix-gc.log";
      StandardErrorPath = "/var/log/nix-gc.log";
    };
  };

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

    always-allow-substitutes = false

    trusted-users = ${config.user.name} root
    substituters = https://suspen.cachix.org?priority=20 https://avoidtuna.mirrors.cernet.edu.cn/nix-channels/store https://cache.nixos.org https://cache.numtide.com
    trusted-public-keys = suspen.cachix.org-1:RU+fX6MttiKajapdYBEOEbq/nuQGl5Qb8BTPTkLs4TU= niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g= cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
    http-connections = 50
    max-substitution-jobs = 32

    connect-timeout = 5
    stalled-download-timeout = 15
    narinfo-cache-negative-ttl = 86400
  '';

  environment.profiles = lib.mkOrder 750 [
    "${config.home.stateDir}/nix/profile"
  ];

  # macOS
  # Host & User identity
  system.primaryUser = config.user.name;

  security.pam.services.sudo_local.touchIdAuth = true;

  system.defaults = {
    dock.autohide = true;
    dock.mru-spaces = false;

    finder = {
      AppleShowAllExtensions = true;
      FXPreferredViewStyle = "clmv";
      ShowPathbar = true;
      ShowStatusBar = true;
      _FXShowPosixPathInTitle = true;
      FXDefaultSearchScope = "SCcf";
    };

    loginwindow.GuestEnabled = false;
    NSGlobalDomain = {
      AppleICUForce24HourTime = true;
      AppleInterfaceStyle = "Dark";

      KeyRepeat = 2;
      InitialKeyRepeat = 15;
      ApplePressAndHoldEnabled = false;
    };
  };

  environment.etc."homebrew/brew.env".text = ''
    HOMEBREW_SYSTEM_ENV_TAKES_PRIORITY=1
    HOMEBREW_API_DOMAIN=https://avoidtuna.mirrors.cernet.edu.cn/homebrew-bottles/api
    HOMEBREW_BOTTLE_DOMAIN=https://avoidtuna.mirrors.cernet.edu.cn/homebrew-bottles
    HOMEBREW_BREW_GIT_REMOTE=https://avoidtuna.mirrors.cernet.edu.cn/homebrew/brew.git
    HOMEBREW_CORE_GIT_REMOTE=https://avoidtuna.mirrors.cernet.edu.cn/homebrew/homebrew-core.git
    HOMEBREW_PIP_INDEX_URL=https://avoidtuna.mirrors.cernet.edu.cn/pypi/web/simple
  '';

  homebrew = {
    enable = true;
    global.brewfile = true;
    enableFishIntegration = true;
    onActivation = {
      extraFlags = [ "--verbose" ];
      autoUpdate = false;
      upgrade = false;
      cleanup = "none";
    };
  };
}
