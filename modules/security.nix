{ ... }:
{
  security.pam = {
    # NixOS uses root-managed /etc/ssh/authorized_keys.d/$ruser and
    # preserves SSH_AUTH_SOCK for sudo. Password authentication remains a fallback.
    rssh.enable = true;
    services.sudo.rssh = true;
  };
}
