# Option shims for sops-nix's darwin backend.
{ lib, ... }:

let
  unitsOption = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    example = [ "sshd.service" ];
  };

  shim = {
    restartUnits = unitsOption;
    reloadUnits = unitsOption;
  };
in
{
  options = {
    sops.templates = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule { options = shim; });
    };

    sops.secrets = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule { options = shim; });
    };
  };
}
