# Linux-only namespaces used by shared modules; unused on Darwin.
{ lib, ... }: {
  options = {
    # Still used by shared ingress code and UCAS's render-only use on Darwin.
    systemd = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Parity shim for shared Linux-first service wiring; unused on darwin.";
    };

    services.caddy = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Parity shim for shared Linux Caddy wiring; unused on darwin.";
    };

    services.tailscale.serve = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Parity shim for shared Linux Serve wiring; unused on darwin.";
    };

    users.defaultUserShell = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "Parity shim for the NixOS default user shell; unused on darwin.";
    };

    # nix-darwin's user submodule lacks the initial-password options. Redeclare
    # only `type`: the module system merges the extra submodule options into
    # nix-darwin's, but restating default/description/example/apply would throw.
    users.users = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options.initialHashedPassword = lib.mkOption {
          type = with lib.types; nullOr (passwdEntry str);
          default = null;
          description = "Parity shim for the NixOS initial password hash; unused on darwin.";
        };
      });
    };
  };
}
