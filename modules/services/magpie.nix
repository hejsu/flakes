# Magpie LLM gateway (official OCI container image).
{ config, lib, services, ... }:

let cfg = config.modules.services.magpie; in {
  options.modules.services.magpie = {
    enable = lib.mkEnableOption "Magpie LLM gateway";

    ingress = lib.mkOption {
      type = services.ingressType;
      default = { };
    };
  };

  config = lib.mkIf cfg.enable {
    modules.ingress.tailnet = cfg.ingress.tailnet;
    modules.ingress.caddy = cfg.ingress.caddy;

    sops.secrets."magpie-web-key" = { };

    sops.templates."magpie.env" = {
      restartUnits = [ "${config.virtualisation.oci-containers.containers.magpie.serviceName}.service" ];
      content = ''
        MAGPIE_WEB_KEY=${config.sops.placeholder."magpie-web-key"}
      '';
    };

    virtualisation.oci-containers.containers.magpie = {
      image = "ghcr.io/yetone/magpie:latest";
      networks = [ "host" ];
      environment.MAGPIE_ADDR = "127.0.0.1:3425";
      environmentFiles = [ config.sops.templates."magpie.env".path ];
      volumes = [ "/var/lib/magpie:/config" ];
      cmd = [ "web" "--addr" "127.0.0.1:3430" "--no-open" ];
    };

    systemd.tmpfiles.rules = [ "d /var/lib/magpie 0700 65532 65532 -" ];
  };
}
