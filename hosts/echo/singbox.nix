{ config, lib, pkgs, ... }: {
  modules.networking.singbox.subscription.enable = true;

  sops.secrets = {
    "singbox-ss-server-key".restartUnits = [ "sing-box.service" ];
    "singbox-ss-user0-key".restartUnits = [ "sing-box.service" ];
  };

  services.sing-box.settings = {
    inbounds = [
      {
        type = "shadowsocks";
        tag = "gw-ss";
        listen = "::";
        listen_port = 38443;
        network = "tcp";
        method = "2022-blake3-aes-128-gcm";
        password._secret = config.sops.secrets."singbox-ss-server-key".path;
        users = [
          {
            name = "user0";
            password._secret = config.sops.secrets."singbox-ss-user0-key".path;
          }
        ];
      }
      {
        type = "socks";
        tag = "egress-socks";
        listen = "127.0.0.1";
        listen_port = 1080;
        users = [
          { username = "egress-1"; password = ""; }
          { username = "egress-2"; password = ""; }
        ];
      }
    ];

    outbounds = [
      { type = "direct"; tag = "gw-direct"; }
    ];

    route.rules = [
      {
        inbound = [ "gw-ss" ];
        auth_user = [ "user0" ];
        domain = [ "cpa.blenny-ayu.ts.net" ];
        network = "tcp";
        port = [ 80 ];
        action = "route";
        outbound = "gw-direct";
        # Publish the existing CPA and Keeper entry through a fixed local backend.
        override_address = "127.0.0.1";
        override_port = 8315;
      }
      {
        inbound = [ "gw-ss" ];
        action = "reject";
      }
      # Bind local routing identities to subscription-provided outbounds.
      {
        inbound = [ "egress-socks" ];
        auth_user = [ "egress-1" ];
        action = "route";
        outbound = "Hong Kong | 07";
      }
      {
        inbound = [ "egress-socks" ];
        auth_user = [ "egress-2" ];
        action = "route";
        outbound = "Hong Kong | 08";
      }
    ];
  };

  networking.firewall = {
    trustedInterfaces = [ "tun0" ];
    allowedTCPPorts = [ 38443 ];
    interfaces.tailscale0.allowedTCPPorts = [ 9091 ];
  };

  # sing-box manages TUN routing; the Tailnet profile selects loose firewall RPF.
  # Previous global overrides retained for deployment comparison.
  # boot.kernel.sysctl = {
  #   "net.ipv4.ip_forward" = 1;
  #   "net.ipv4.conf.all.rp_filter" = 2;
  #   "net.ipv4.conf.default.rp_filter" = 2;
  # };

  systemd.services.singbox-publish =
    let
      gateway = lib.findFirst
        (inbound: (inbound.tag or "") == "gw-ss")
        (throw "singbox-publish: gw-ss inbound not found")
        config.services.sing-box.settings.inbounds;

      server = lib.head config.services.cloudflare-ddns.ip6Domains;

      exportUser = user:
        assert builtins.match "[A-Za-z0-9_-]+" user.name != null;
        ''
          server_key=$(<${lib.escapeShellArg gateway.password._secret})
          user_key=$(<${lib.escapeShellArg user.password._secret})

          password=$(printf '%s:%s' "$server_key" "$user_key" | jq -sRr @uri)
          name=$(printf '%s' ${lib.escapeShellArg user.name} | jq -sRr @uri)

          printf 'ss://%s:%s@%s:%s#%s\n' \
            ${lib.escapeShellArg gateway.method} \
            "$password" \
            ${lib.escapeShellArg server} \
            ${lib.escapeShellArg (toString gateway.listen_port)} \
            "$name" \
            > "$RUNTIME_DIRECTORY"/${lib.escapeShellArg "${user.name}.txt"}
        '';
    in {
      description = "Prepare per-user Shadowsocks subscription files";

      serviceConfig = {
        Type = "oneshot";
        StateDirectory = "singbox-publish";
        StateDirectoryMode = "0700";
        RuntimeDirectory = "singbox-publish";
        RuntimeDirectoryMode = "0700";
        UMask = "0077";
      };

      path = [ pkgs.jq pkgs.openssh ];

      script = ''
        set -euo pipefail

        # Provision the publishing identity manually; never replace it here.
        ssh-keygen -y -P "" -f "$STATE_DIRECTORY/id_ed25519" > /dev/null

        ${lib.concatMapStringsSep "\n" exportUser gateway.users}
      '';
    };
}
