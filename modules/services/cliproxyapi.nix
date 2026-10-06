# CLIProxyAPI.
#
# The config is a plain file the user owns and edits: CLIProxyAPI watches it and
# applies changes without a restart, so it must live OUTSIDE the Nix store.
#
# Not built on nixpkgs' services.cliproxyapi -- it hardcodes ExecStart at its own
# rendered config, so using it here would mean forcing three settings back.
# Running as the login user (like the launchd agent in
# modules/_darwin/cliproxyapi.nix) keeps the config in $HOME readable.
{ config, lib, pkgs, ... }:

let cfg = config.modules.services.cliproxyapi; in {
  options.modules.services.cliproxyapi = {
    enable = lib.mkEnableOption "CLIProxyAPI user service";

    configFile = lib.mkOption {
      type = lib.types.either lib.types.path lib.types.str;
      default = "${config.home.configDir}/cli-proxy-api/config.yaml";
      description = ''
        Config file the service reads and watches. Keep it outside the Nix
        store so edits hot-reload instead of needing a rebuild.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.cliproxyapi = {
      description = "OpenAI/Gemini/Claude/Codex compatible API proxy";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      serviceConfig = {
        User = config.user.name;
        ExecStart = "${lib.getExe pkgs.cliproxyapi} -config ${cfg.configFile}";
        WorkingDirectory = "${config.home.stateDir}/cliproxyapi";
        Restart = "on-failure";
        RestartSec = 5;

        NoNewPrivileges = true;
        PrivateTmp = true;
      };
    };

    systemd.tmpfiles.rules = [
      "d ${config.home.stateDir}/cliproxyapi 0700 ${config.user.name} - -"
    ];
  };
}
