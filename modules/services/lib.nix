# Service capability abstraction for modules.services.
#
# Host view: a service owns its own config, ingress and (later) backup:
#
#   modules.services.magpie.ingress = { … };
#
# Implementation view: ingress is its own module. Each service hands its slice
# to the shared aggregation options:
#
#   config.modules.ingress.tailnet = cfg.ingress.tailnet;
#
# `modules.ingress.*` is defined by any module; the merged definitions are
# forwarded with mkAliasDefinitions, so priority markers and the target
# option's own merging/conflict rules are preserved. This module knows nothing
# about individual services and stays platform-agnostic: the types are borrowed
# from the native backends, falling back to plain attrs where Darwin shims exist.
{ config, options, lib, ... }:

let
  ingressType = lib.types.submodule {
    options = {
      tailnet = lib.mkOption {
        type = lib.types.attrs;
        default = { };
      };
      caddy = lib.mkOption {
        type = lib.types.attrs;
        default = { };
      };
    };
  };

  ingress = config.modules.ingress;
in
{
  options.modules.ingress = {
    tailnet = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Tailscale Serve services contributed by services.";
    };
    caddy = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Caddy virtual hosts contributed by services.";
    };
  };

  config = {
    # Services reference this type when declaring their own `ingress` option.
    _module.args.services = {
      inherit ingressType;
    };

    services.tailscale = lib.mkIf (ingress.tailnet != { }) {
      enable = lib.mkDefault true;
      serve = {
        enable = true;
        # Forward definitions (not just the merged value) so mkForce/mkDefault
        # and the backend's own conflict detection still apply.
        services = lib.mkAliasDefinitions options.modules.ingress.tailnet;
      };
    };

    # Apply Serve configuration once the Tailnet is ready.
    systemd.services.tailscale-serve = lib.mkIf (ingress.tailnet != { }) {
      requires = [ "tailscale-online.target" ];
      after = [ "tailscale-online.target" ];
    };

    services.caddy = lib.mkIf (ingress.caddy != { }) {
      enable = true;
      virtualHosts = lib.mkAliasDefinitions options.modules.ingress.caddy;
    };

    assertions = [
      {
        assertion = ingress.tailnet == { } || (config.services.tailscale.serve.configFile or null) == null;
        message = "modules.ingress.tailnet cannot be combined with services.tailscale.serve.configFile.";
      }
      {
        assertion = ingress.caddy == { } || (config.services.caddy.settings or { }) == { };
        message = "modules.ingress.caddy uses virtualHosts and cannot be combined with services.caddy.settings.";
      }
      {
        assertion = ingress.caddy == { } || !(options.services.caddy.configFile.isDefined or false);
        message = "modules.ingress.caddy uses virtualHosts, which a custom services.caddy.configFile would override.";
      }
    ];
  };
}
