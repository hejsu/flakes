{
  system = "aarch64-darwin";

  profiles = {
    user = "suspen";
    role = "laptop";
  };

  modules = {
    sops = {
      enable = true;
    };

    shell = {
      fish.enable = true;
      git.enable = true;
      direnv.enable = true;
      nvim.enable = true;
    };

    dev = {
      typst.enable = true;
      python.enable = true;
    };

    services = {
      cliproxyapi.enable = true;
      ucasrun.enable = true; # set through Shortcuts
    };
  };

  settings = { self, lib, config, pkgs, ... }: {
    time.timeZone = "Asia/Shanghai";

    system.stateVersion = 6;

    environment.systemPackages = [
      (pkgs.writeShellScriptBin "fix-ipv6-route" ''
        export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
        exec ${pkgs.python3}/bin/python3 ${./assets/fix-ipv6-route.py} "$@"
      '')
    ];

    security.sudo.extraConfig = ''
      suspen ALL=(root) NOPASSWD: /run/current-system/sw/bin/fix-ipv6-route
    '';

    home.sessionVariables = {
      SSH_AUTH_SOCK = "${config.home.dir}/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh";
      VSCODE_CLI_DATA_DIR = "${config.home.dir}/Applications/vscode/code-portable-data/cli-data";
    };

    launchd.user.envVariables = {
      SSH_AUTH_SOCK = "${config.home.dir}/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh";
      GEMINI_CLI_HOME = "${config.home.configDir}/gemini";
      COPILOT_HOME = "${config.home.configDir}/copilot";
      CODEX_HOME = "${config.home.configDir}/codex";
    };

    home.configFile = {
      "kitty".source = "${self.configDir}/kitty";
      "zed/settings.json".source = "${self.configDir}/zed/settings.json";
    };

    user.packages = with pkgs; [
      dash

      self.packages.bitsrun # with shortcuts
      self.packages.atst
    ];

    homebrew = {
      brews = [
        "docker"
        "docker-compose"
        "gcc"

        "opencode"
      ];

      casks = [
        "kitty"
        "zed"
        "wechat"
        "qq"
        "google-chrome"
        "zotero"
        "tencent-meeting"
        "visual-studio-code"
        "secretive"

        "tailscale-app"
        "sfm"

        "keka"
        "appcleaner"
        "coteditor"

        "windows-app"
      ];
    };
  };
}
