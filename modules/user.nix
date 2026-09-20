# modules/core.nix --- Core dotfiles module (user alias & global options)
{ lib, options, config, pkgs, ... }:

{
  options = {
    modules = {};

    # Creates a simpler, polymorphic alias for users.users.$USER.
    user = lib.mkOption {
      type = options.users.users.type.nestedTypes.elemType;
      default = {};
      description = "The primary user account configuration";
    };
  };

  config = {
    assertions = [{
      assertion = config.user.name != "";
      message = "config.user.name must not be empty!";
    }];

    user = {
      home = lib.mkDefault (
        if pkgs.stdenv.isDarwin then 
          "/Users/${config.user.name}"
        else 
          "/home/${config.user.name}"
      );
    };

    users.users.${config.user.name} = lib.mkAliasDefinitions options.user;
  };
}

