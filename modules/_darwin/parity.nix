# Namespaces the shared Linux-first layer writes to that macOS does not have.
#
# Declaring them here -- rather than leaning on `_module.freeformType` alone --
# is required: a definition at a wholly undeclared top-level path makes
# evaluation recurse when the defining module also reads `config`/`pkgs`, which
# every real module does (`lib.mkIf cfg.enable` is enough to trigger it).
# See lib/modules.nix:307 (`config._module.check && ... freeformType == null`).
#
# Values are accepted and dropped; nothing on darwin consumes them. This is one
# shim for the whole namespace, so new services need no changes here.
{ lib, ... }: {
  options = {
    systemd = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Parity shim for shared Linux-first service wiring; unused on darwin.";
    };

    boot = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Parity shim for shared Linux-first boot/sysctl wiring; unused on darwin.";
    };
  };
}
