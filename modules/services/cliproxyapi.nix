# CLIProxyAPI.
{ self, config, lib, pkgs, ... }:

let
  cfg = config.modules.services.cliproxyapi;

  seedConfig = (pkgs.formats.yaml { }).generate "cliproxyapi-seed.yaml" {
    config-version = 8;
    server = {
      host = "127.0.0.1";
      port = 8317;
    };
    oauth.auth-dir = "/var/lib/cliproxyapi/auth";
    observability.usage.usage-statistics-enabled = true;
  };
in {
  options.modules.services.cliproxyapi = {
    enable = lib.mkEnableOption "CLIProxyAPI";
    tailsvc = lib.mkEnableOption "expose via Tailscale Serve";
  };

  config = lib.mkIf cfg.enable {
    sops.secrets = {
      "cpa-management-key" = { };
      "github-token" = { };
    };

    sops.templates = {
      "cliproxyapi.env" = {
        mode = "0400";
        content = ''
          MANAGEMENT_PASSWORD="${config.sops.placeholder."cpa-management-key"}"
          GITHUB_TOKEN="${config.sops.placeholder."github-token"}"
        '';
      };

      "cpa-usage-keeper.env" = {
        mode = "0400";
        content = ''
          CPA_MANAGEMENT_KEY="${config.sops.placeholder."cpa-management-key"}"
          LOGIN_PASSWORD="${config.sops.placeholder."cpa-management-key"}"
        '';
      };
    };

    services.caddy = {
      enable = true;
      virtualHosts."http://:8315".extraConfig = ''
        bind 127.0.0.1

        handle / {
          redir * /keeper/
        }
        handle /keeper* {
          reverse_proxy 127.0.0.1:8318
        }
        handle {
          reverse_proxy 127.0.0.1:8317
        }
      '';
    };

    services.tailscale.serve.services = lib.mkIf cfg.tailsvc {
      cpa = {
        advertised = true;
        endpoints."tcp:80" = "tcp://127.0.0.1:8315";
      };
    };

    systemd.services.cliproxyapi = {
      description = "LLM Compatible API Proxy";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      environment.HOME = "/var/lib/cliproxyapi";

      preStart = '' #bash
        if [ ! -e "$STATE_DIRECTORY/config.yaml" ]; then
          install -m 0600 ${seedConfig} "$STATE_DIRECTORY/config.yaml"
        fi
      '';

      serviceConfig = {
        DynamicUser = true;
        StateDirectory = "cliproxyapi";
        StateDirectoryMode = "0700";
        WorkingDirectory = "/var/lib/cliproxyapi";

        EnvironmentFile = config.sops.templates."cliproxyapi.env".path;

        ExecStart = "${lib.getExe self.inputs.llm-agents.packages.cli-proxy-api} -config /var/lib/cliproxyapi/config.yaml";

        Restart = "on-failure";
        RestartSec = 5;

        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" "AF_NETLINK" ];
      };
    };

    systemd.services.cpa-usage-keeper = {
      description = "CPA Usage Keeper";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" "cliproxyapi.service" ];
      wants = [ "network-online.target" "cliproxyapi.service" ];

      environment = {
        CPA_BASE_URL = "http://127.0.0.1:8317";
        APP_HOST = "127.0.0.1";
        APP_PORT = "8318";
        APP_BASE_PATH = "/keeper";
        WORK_DIR = "/var/lib/cpa-usage-keeper";
        AUTH_ENABLED = "true";
      };

      serviceConfig = {
        DynamicUser = true;
        StateDirectory = "cpa-usage-keeper";
        StateDirectoryMode = "0700";
        WorkingDirectory = "/var/lib/cpa-usage-keeper";

        EnvironmentFile = config.sops.templates."cpa-usage-keeper.env".path;

        ExecStart = "${lib.getExe self.inputs.llm-agents.packages.cpa-usage-keeper}";

        Restart = "on-failure";
        RestartSec = 5;

        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" "AF_NETLINK" ];
      };
    };
  };
}
