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
        type = types.submodule {
          options =
            let
              opt = desc: mkOption {
                type = with types; nullOr (either str (listOf str));
                default = null;
                description = desc;
              };
            in
            {
              user = opt "User identity profile (profiles/user/<name>.nix)";
              role = opt "System role profile (profiles/role/<name>.nix)";
              networks = opt "Network profiles (profiles/networks/<name>.nix)";
              hardware = opt "Hardware profiles (profiles/hardware/<name>.nix)";
            };
        };
        default = { };
        description = "Profile selectors matching profiles/<axis>/<name>.nix";
      };

      includes = mkOption {
        type = types.listOf types.deferredModule;
        default = [ ];
        description = "Extra modules to include directly for this host";
      };

      modules = mkOption {
        type = types.attrs;
        default = { };
        description = "High-level dotfiles feature switches";
      };

      hardware = mkOption {
        type = types.deferredModule;
        default = { };
        description = "Hardware, disks, and bootloader configurations";
      };

      settings = mkOption {
        type = types.deferredModule;
        default = { };
        description = "Machine-specific native OS configuration overrides";
      };
    };
  };

  # Validated eval: apply hostSubmodule to fill in defaults.
  evalHost = { module, specialArgs ? { } }:
    (evalModules {
      modules = [ hostSubmodule module ];
      inherit specialArgs;
    }).config;

  # mapHosts only records paths; full eval happens in mkFlake where self exists.
  mapHosts = dir:
    mapAttrs
      (hostName: _:
        dir + "/${hostName}/default.nix"
      )
      (filterAttrs
        (n: v:
          v == "directory"
          && !(hasPrefix "." n)
          && !(hasPrefix "_" n)
          && pathExists (dir + "/${n}/default.nix")
        )
        (readDir dir));
}
