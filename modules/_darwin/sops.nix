# Option shims for sops-nix's darwin backend.
{ config, lib, ... }:

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

  # Linux uses the system-wide key; macOS keeps the user-owned one.
  config.modules.sops.ageKeyFile =
    lib.mkDefault "${config.home.configDir}/sops/age/keys.txt";
}
