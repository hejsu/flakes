{ ss, config, lib, options, ... }:

let cfg = config.modules.sops; in {
  imports = [
    ss.modules.sops-nix.sops
  ];

  options.modules.sops = with lib; with types; {
    enable = mkEnableOption "Sops secret management integration";

    defaultSopsFile = mkOption {
      type = either path str;
      default = ss.sourceDir + "/hosts/${config.networking.hostName}/assets/secrets.yaml";
      description = ''
        Default sops file to use for secrets.
        Defaults to hosts/<hostName>/assets/secrets.yaml if present.
      '';
    };

    ageKeyFile = mkOption {
      type = either path str;
      default = "${config.home.configDir}/sops/age/keys.txt";
      description = "Path to the age private key file.";
    };

    # Alias for sops.secrets
    secrets = mkOption {
      type = options.sops.secrets.type;
      default = { };
      description = "Alias for sops.secrets";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.pathExists cfg.defaultSopsFile;
        message = "modules.sops: defaultSopsFile (${toString cfg.defaultSopsFile}) does not exist. Expected hosts/${config.networking.hostName}/assets/secrets.yaml.";
      }
    ];

    sops = {
      inherit (cfg) defaultSopsFile;
      age = {
        keyFile = cfg.ageKeyFile;
        generateKey = false;
        sshKeyPaths = [ ];
      };
      gnupg = {
        sshKeyPaths = [ ];
      };
      secrets = lib.mkAliasDefinitions options.modules.sops.secrets;
    };
  };
}
