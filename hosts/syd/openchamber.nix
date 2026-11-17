# OpenChamber web UI for OpenCode, with local socket activation.
{ self, config, lib, pkgs, ... }:

{
  user.packages = [
    pkgs.devenv
    self.inputs.llm-agents.packages.opencode2
  ];

  networking.firewall.allowedTCPPorts = [ 6767 ];

  # The UI is reachable from the LAN/tailnet and exposes a shell, so require
  # OpenChamber's own password.
  sops.secrets."openchamber-ui-password" = { };

  sops.templates."openchamber.env" = {
    owner = config.user.name;
    mode = "0400";
    restartUnits = [ "openchamber.service" ];
    content = ''
      OPENCHAMBER_UI_PASSWORD="${config.sops.placeholder."openchamber-ui-password"}"
    '';
  };

  systemd.sockets.openchamber = {
    wantedBy = [ "sockets.target" ];
    socketConfig = {
      ListenStream = "192.168.10.10:6767";
      FreeBind = true;
      Service = "openchamber-proxy.service";
    };
  };

  # A connection starts the backend. No connections for 60m releases it again,
  # which also stops any agent task still running.
  systemd.services.openchamber-proxy = {
    requires = [ "openchamber.socket" ];
    bindsTo = [ "openchamber.service" ];
    after = [ "openchamber.socket" "openchamber.service" ];
    serviceConfig = {
      User = config.user.name;
      Type = "notify";
      ExecStart =
        "${config.systemd.package}/lib/systemd/systemd-socket-proxyd"
        + " --exit-idle-time=60m 127.0.0.1:6768";
    };
  };

  systemd.services.openchamber = {
    description = "OpenChamber web UI for OpenCode";
    unitConfig.StopWhenUnneeded = true;

    environment = {
      HOME = config.home.dir;
      SHELL = "${pkgs.bashInteractive}/bin/bash";

      OPENCHAMBER_HOST = "127.0.0.1";
      OPENCHAMBER_DATA_DIR = "${config.home.dataDir}/openchamber";
      # Default is ~/.config/openchamber/chats even with a custom data dir.
      OPENCHAMBER_CHATS_DIR = "${config.home.dataDir}/openchamber/chats";
      # Advertised in QR/pairing links. This name resolves to Tailscale's
      # 4via6 address for 192.168.10.10; LAN-only devices use the bare IP.
      OPENCHAMBER_LAN_URL = "http://syd.lan.aoran.eu.org:6767";
      OPENCHAMBER_TERMINAL_SHELL = "${pkgs.bashInteractive}/bin/bash";

      # Pinned so the managed OpenCode server keeps its port across restarts.
      OPENCODE_PORT = "6769";
    };

    # OpenChamber persists its own JWT secret in this directory, so sessions
    # survive restarts and global sign-out keeps working.
    preStart = ''
      install -d -m 0700 "${config.home.dataDir}/openchamber"
    '';

    postStart = ''
      ${pkgs.bashInteractive}/bin/bash -c '
        for ((i = 0; i < 170; i++)); do
          if (exec 3<>/dev/tcp/127.0.0.1/6768) 2>/dev/null; then exit 0; fi
          sleep 1
        done
        exit 1
      '
    '';

    serviceConfig = {
      User = config.user.name;
      Group = config.user.group;
      WorkingDirectory = config.home.dir;

      EnvironmentFile = [
        config.sops.templates."openchamber.env".path
        # Optional: extra environment for agents (API keys, proxies, …).
        "-${config.home.dataDir}/openchamber/env"
      ];

      # A login shell loads /etc/profile, so agents get the same PATH and
      # environment.variables as an interactive login (nix, direnv, devenv,
      # comma, NPM_CONFIG_*, XDG_*, …). The wrapper adds git and ripgrep.
      ExecStart =
        "${pkgs.bashInteractive}/bin/bash -lc "
        + lib.escapeShellArg (
          "exec ${lib.getExe self.inputs.llm-agents.packages.openchamber}"
          + " --foreground --port 6768"
        );

      Restart = "on-failure";
      RestartSec = 2;
      TimeoutStartSec = 180;
      TimeoutStopSec = 30;
    };
  };
}
