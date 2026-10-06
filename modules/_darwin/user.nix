{ lib, config, ... }: {
  options.users.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        isNormalUser = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "NixOS account kind; accepted and ignored on darwin.";
        };
        isSystemUser = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "NixOS account kind; accepted and ignored on darwin.";
        };
        group = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "NixOS primary group; accepted and ignored on darwin.";
        };
        extraGroups = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "NixOS supplementary groups; accepted and ignored on darwin.";
        };
      };
    });
  };

  config.user.home = lib.mkDefault "/Users/${config.user.name}";
}
