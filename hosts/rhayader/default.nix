{
  system = "aarch64-darwin";

  profiles = {
    user = "suspen";
    role = "laptop";
    networks = [ "ucas" ];
  };

  modules = {
    apps = {
      emacs.enable = true;
      kitty.enable = true;
      zed.enable = true;
    };

    sops.enable = true;

    shell = {
      fish.enable = true;
      git.enable = true;
      nvim.enable = true;
      direnv.enable = true;
      comma.enable = true;
    };

    dev = {
      typst.enable = true;
      python.enable = true;
      node.enable = true;
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

    # Undo: sudo sysctl -w net.inet6.ip6.use_tempaddr=1 net.inet6.ip6.prefer_tempaddr=1
    launchd.daemons.ipv6-privacy = {
      script = ''
        /usr/sbin/sysctl -w \
          net.inet6.ip6.use_tempaddr=0 \
          net.inet6.ip6.prefer_tempaddr=0
      '';
      serviceConfig.RunAtLoad = true;
    };

    security.sudo.extraConfig =
      let
        script = "/etc/profiles/per-user/${config.user.name}/bin/ucas-ipv6-ctl";
      in
      ''
        ${config.user.name} ALL=(root) NOPASSWD: ${script} "", ${script} clear
      '';

    user.packages = with pkgs; [
      dash
      mtr
      nil

      self.packages.atst
      self.packages.bitsrun

      (pkgs.writeShellScriptBin "ucas-ipv6-ctl"
        (builtins.readFile ./assets/ucas-ipv6-ctl.sh))

      (pkgs.writeShellScriptBin "opencode" ''
        exec ${self.inputs.llm-agents.packages.opencode2}/bin/opencode2 "$@"
      '')
    ];

    homebrew = {
      brews = [
        "gcc"
      ];

      casks = [
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
