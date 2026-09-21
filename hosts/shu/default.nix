{
  system = "aarch64-darwin";

  profiles = {
    user = "suspen";
    role = "laptop";
  };

  modules = {
    xdg.enable = true;

    shell = {
      fish.enable = true;
      git.enable = true;
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
      cc.enable = true;
      typst.enable = true;
      python.enable = true;
    };

    services = {
      cliproxyapi.enable = true;
    };
  };

  settings = { ss, lib, config, ... }: {
    system.stateVersion = 6;

    home.sessionVariables = {
      SSH_AUTH_SOCK = "${config.home.dir}/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh";
      VSCODE_CLI_DATA_DIR = "${config.home.dir}/Applications/vscode/code-portable-data/cli-data";
    };

    launchd.user.envVariables = {
      GEMINI_CLI_HOME = "${config.home.configDir}/gemini";
      COPILOT_HOME = "${config.home.configDir}/copilot";
      CODEX_HOME = "${config.home.configDir}/codex";
    };

    home.configFile = {
      "kitty".source = "${ss.configDir}/kitty";
      "zed/settings.json".source = "${ss.configDir}/zed/settings.json";
    };

    homebrew = {
      brews = [
        "docker"
        "docker-compose"
        "gcc"
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
