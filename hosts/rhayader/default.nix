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
      node.enable = true;
    };

    services = {
      ucas-ipv6-fix.enable = true;
      ucasrun.enable = true;
    };
  };

  settings = { self, config, pkgs, ... }: {
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

      "emacs/early-init.el".source = "${self.configDir}/emacs/early-init.el";
      "emacs/init.el".source = "${self.configDir}/emacs/init.el";
      "emacs/cfg".source = "${self.configDir}/emacs/cfg";
      "emacs/straight-versions.el".source = "${self.configDir}/emacs/straight-versions.el";
    };

    user.packages = with pkgs; [
      dash
      mtr
      nil

      self.packages.atst

      (pkgs.writeShellScriptBin "opencode" ''
        exec ${self.inputs.llm-agents.packages.opencode2}/bin/opencode2 "$@"
      '')
    ];

    homebrew = {
      taps = [ "d12frosted/emacs-plus" ];

      brews = [
        "gcc"
      ];

      casks = [
        "emacs-plus-app"

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
