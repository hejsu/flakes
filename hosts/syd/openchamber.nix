# OpenChamber web UI for OpenCode, with local socket activation.
{ self, config, lib, pkgs, ... }:

{
  user.packages = [
    pkgs.devenv
    self.inputs.llm-agents.packages.opencode2
  ];

  networking.firewall.allowedTCPPorts = [ 6767 ];

  systemd.sockets.openchamber = {
    wantedBy = [ "sockets.target" ];
    socketConfig = {
      ListenStream = "192.168.10.10:6767";
      FreeBind = true;
      Service = "openchamber-proxy.service";
    };
  };

  # A connection starts the backend. No connections for 10m releases it again.
  systemd.services.openchamber-proxy = {
    requires = [ "openchamber.socket" "openchamber.service" ];
    after = [ "openchamber.socket" "openchamber.service" ];
    serviceConfig = {
      User = config.user.name;
      Type = "notify";
      ExecStart =
        "${config.systemd.package}/lib/systemd/systemd-socket-proxyd"
        + " --exit-idle-time=10m 127.0.0.1:6768";
    };
  };

  systemd.services.openchamber = {
    description = "OpenChamber web UI for OpenCode";
    unitConfig.StopWhenUnneeded = true;

    # Extra tools for OpenCode's shell tool and project actions. NixOS already
    # defaults to coreutils/findutils/gnugrep/gnused/systemd here.
    path = with pkgs; [
      bashInteractive
      curl
      git
      jq
      ripgrep
    ];

    environment = {
      HOME = config.home.dir;
      SHELL = "${pkgs.bashInteractive}/bin/bash";
      DIRENV_CONFIG = "/etc/direnv";
      COMMA_NIXPKGS_FLAKE = "github:NixOS/nixpkgs/${self.inputs.nixpkgs.rev}";

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

    preStart = ''
      install -d -m 0700 "${config.home.dataDir}/openchamber"

      # Stable token secret, generated once. No UI password on purpose.
      umask 077
      if [ ! -s "${config.home.dataDir}/openchamber/jwt-secret" ]; then
        ${pkgs.openssl}/bin/openssl rand -base64 36 > "${config.home.dataDir}/openchamber/jwt-secret"
      fi
    '';

    postStart = ''
      ${pkgs.bashInteractive}/bin/bash -c '
        for ((i = 0; i < 60; i++)); do
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

      # Optional: extra environment for agents (API keys, proxies, …).
      EnvironmentFile = "-${config.home.dataDir}/openchamber/env";

      ExecStart = toString (pkgs.writeShellScript "openchamber-start" ''
        export OPENCODE_JWT_SECRET="$(cat ${config.home.dataDir}/openchamber/jwt-secret)"
        exec ${lib.getExe self.inputs.llm-agents.packages.openchamber} --foreground --port 6768
      '');

      Restart = "on-failure";
      RestartSec = 2;
      TimeoutStartSec = 180;
      TimeoutStopSec = 30;
    };
  };
}
