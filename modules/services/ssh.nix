# OpenSSH server, key-only. Opt-in: darwin hosts use the system sshd instead.
{ config, lib, ... }:

let cfg = config.modules.services.ssh; in {
  options.modules.services.ssh = {
    enable = lib.mkEnableOption "OpenSSH server (key-only)";
  };

  config = lib.mkIf cfg.enable {
    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        # Keep sessions alive through cloud load balancers that drop idle TCP.
        ClientAliveInterval = 180;
      };
    };
  };
}
