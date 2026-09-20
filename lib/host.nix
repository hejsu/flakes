{ lib }:

with lib;
rec {
  # Submodule schema for a Host definition
  hostSubmodule = {
    options = {
      system = mkOption {
        type = types.enum [
          "aarch64-darwin"
          "x86_64-linux"
          "aarch64-linux"
        ];
        description = "Target host architecture / platform";
      };

      profiles = mkOption {
        type = types.attrsOf (types.nullOr types.str);
        default = {};
        description = "Profile selectors matching profiles/<key>/<val>.nix";
      };

      modules = mkOption {
        type = types.attrs;
        default = {};
        description = "High-level dotfiles feature switches";
      };

      hardware = mkOption {
        type = types.deferredModule;
        default = {};
        description = "Hardware, disks, and bootloader configurations";
      };

      setting = mkOption {
        type = types.deferredModule;
        default = {};
        description = "Machine-specific native OS configuration overrides";
      };
    };
  };

  # Evaluates and validates a host module against hostSubmodule
  evalHost = module:
    (evalModules {
      modules = [ hostSubmodule module ];
    }).config;

  # Discovers hosts from directory
  mapHosts = dir:
    mapAttrs (hostName: _:
      evalHost (dir + "/${hostName}/default.nix")
    ) (filterAttrs (n: v:
        v == "directory"
        && !(hasPrefix "." n)
        && !(hasPrefix "_" n)
        && pathExists (dir + "/${n}/default.nix")
      ) (readDir dir));
}
