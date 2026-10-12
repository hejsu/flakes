{ self, config, lib, pkgs, options, ... }:

let cfg = config.modules.sops; in {
  imports = [ self.modules.sops-nix.sops ];

  options.modules.sops = with lib; with types; {
    enable = mkEnableOption "Sops secret management integration";

    ageKeyFile = mkOption {
      type = with types; nullOr (either path str);
      default = "${config.home.configDir}/sops/age/keys.txt";
      description = ''
        Path to the age private key file.
        Defaults to the user-owned key; set to null to rely solely on
        SSH-derived identities (sops-nix defaults to the host ed25519 key).
      '';
    };

    secrets = mkOption {
      type = options.sops.secrets.type;
      default = { };
      description = "Alias for sops.secrets";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.pathExists (self.sourceDir + "/hosts/${config.networking.hostName}/assets/secrets.yaml");
        message = "modules.sops: defaultSopsFile does not exist. Expected hosts/${config.networking.hostName}/assets/secrets.yaml.";
      }
    ];

    environment.systemPackages = [ pkgs.sops pkgs.age ];

    sops = {
      defaultSopsFile = self.sourceDir + "/hosts/${config.networking.hostName}/assets/secrets.yaml";

      age = {
        keyFile = cfg.ageKeyFile;
        generateKey = true;
        sshKeyPaths = [ ];
      };
      gnupg.sshKeyPaths = [ ];

      secrets = lib.mkAliasDefinitions options.modules.sops.secrets;
    };
  };
}
