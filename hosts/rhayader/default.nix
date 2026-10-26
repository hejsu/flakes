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
      ucas-ipv6-fix.enable = true;
    };
  };

  settings = { self, lib, config, pkgs, ... }: {
    time.timeZone = "Asia/Shanghai";

    system.stateVersion = 6;

    home.sessionVariables = {
      SSH_AUTH_SOCK = "${config.home.dir}/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh";
      VSCODE_CLI_DATA_DIR = "${config.home.dir}/Applications/vscode/code-portable-data/cli-data";
    };

    launchd.user.envVariables = {
      SSH_AUTH_SOCK = "${config.home.dir}/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh";
      COPILOT_HOME = "${config.home.configDir}/copilot";
    };

    home.configFile = {
      "kitty".source = "${self.configDir}/kitty";
      "zed/settings.json".source = "${self.configDir}/zed/settings.json";
    };

    user.packages = with pkgs; [
      dash

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
