{ config, ... }: {
  modules.networking.singbox.enable = true;

  # Provision these values in assets/secrets.yaml before deploying.
  sops.secrets = {
    "reality-private-key".restartUnits = [ "sing-box.service" ];
    "reality-user0-uuid".restartUnits = [ "sing-box.service" ];
  };

  services.sing-box.settings = {
    dns.servers = [
      { type = "local"; tag = "local"; }
    ];

    inbounds = [
      {
        type = "vless";
        tag = "reality-in";
        listen = "::";
        listen_port = 443;
        users = [
          {
            name = "user0";
            uuid._secret = config.sops.secrets."reality-user0-uuid".path;
            flow = "xtls-rprx-vision";
          }
        ];
        tls = {
          enabled = true;
          server_name = "www.microsoft.com";
          reality = {
            enabled = true;
            handshake = {
              server = "www.microsoft.com";
              server_port = 443;
            };
            private_key._secret = config.sops.secrets."reality-private-key".path;
            short_id = [ "cf241d4048878880" ];
          };
        };
      }
    ];

    outbounds = [
      { type = "direct"; tag = "direct"; }
    ];

    route = {
      default_domain_resolver = "local";
      rules = [
        { action = "resolve"; }
        # This is an Internet exit, not an entry to az's LAN or Tailnet.
        { ip_is_private = true; action = "reject"; }
      ];
      final = "direct";
    };
  };

  networking.firewall.allowedTCPPorts = [ 443 ];
}
