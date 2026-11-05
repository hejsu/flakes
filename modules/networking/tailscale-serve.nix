# Publish local services on the tailnet.
{ config, lib, options, ... }:

let cfg = config.modules.networking.tailscale-serve; in {
  options.modules.networking.tailscale-serve = {
    enable = lib.mkEnableOption "Tailscale Serve";

    services = lib.mkOption {
      type = options.services.tailscale.serve.services.type or lib.types.attrs;
      default = { };
      description = "Named Tailscale Services and their endpoint mappings.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.tailscale.serve = {
      enable = true;
      services = lib.mkAliasDefinitions
        options.modules.networking.tailscale-serve.services;
    };
  };
}
