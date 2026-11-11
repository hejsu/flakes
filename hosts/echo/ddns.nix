{ config, ... }: {
  sops.secrets."cloudflare-api-token-dns-edit-zone-read" = { };

  sops.templates."cloudflare-ddns-env" = {
    restartUnits = [ "cloudflare-ddns.service" ];
    owner = "cloudflare-ddns";
    group = "cloudflare-ddns";
    mode = "0440";
    content = ''
      CLOUDFLARE_API_TOKEN="${config.sops.placeholder."cloudflare-api-token-dns-edit-zone-read"}"
    '';
  };

  services.cloudflare-ddns = {
    enable = true;
    credentialsFile = config.sops.templates."cloudflare-ddns-env".path;

    ip6Domains = [ "echo.aoran.eu.org" ];
    provider.ipv4 = "none";
    provider.ipv6 = "local";

    ttl = 60;
  };
}
