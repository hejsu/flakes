# Caddy with the Cloudflare DNS-01 plugin. Cross-host edge capability.
{ config, lib, pkgs, ... }:

let cfg = config.modules.services.caddy; in {
  options.modules.services.caddy = {
    enable = lib.mkEnableOption "Caddy with Cloudflare DNS-01";
  };

  config = lib.mkIf cfg.enable {
    sops.secrets."cloudflare-api-token-dns-edit-zone-read" = { };

    sops.templates."caddy-cloudflare-env" = {
      restartUnits = [ "caddy.service" ];
      owner = "caddy";
      group = "caddy";
      mode = "0440";
      content = ''
        CF_API_TOKEN="${config.sops.placeholder."cloudflare-api-token-dns-edit-zone-read"}"
      '';
    };

    services.caddy = {
      enable = true;
      email = "suspen@outlook.sk";
      environmentFile = config.sops.templates."caddy-cloudflare-env".path;
      globalConfig = ''
        acme_dns cloudflare {env.CF_API_TOKEN}
      '';
      package = pkgs.caddy.withPlugins {
        plugins = [ "github.com/caddy-dns/cloudflare@v0.2.4" ];
        hash = "sha256-QSiwKqKvSxhksWBF4/MlBOpyXba5xOQ2sRwA0R7399E=";
      };
    };
  };
}
