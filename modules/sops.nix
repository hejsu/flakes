{ self, config, lib, pkgs, ... }:

let cfg = config.modules.sops; in {
  imports = [ self.modules.sops-nix.sops ];

  options.modules.sops = with lib; with types; {
    enable = mkEnableOption "Sops secret management integration";

    ageKeyFile = mkOption {
      type = with types; nullOr (either path str);
      default = "/var/lib/sops-nix/key.txt";
      description = ''
        Path to the age private key file.
        Defaults to the system-wide key used by sops-nix on Linux; Darwin
        overrides it with the user-owned key. Set to null to rely solely on
        SSH-derived identities (sops-nix defaults to the host ed25519 key).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.pathExists (self.hostDir + "/assets/secrets.yaml");
        message = "modules.sops: defaultSopsFile does not exist. Expected ${self.hostDir}/assets/secrets.yaml.";
      }
    ];

    environment.systemPackages = [ pkgs.sops pkgs.age ];

    sops = {
      defaultSopsFile = self.hostDir + "/assets/secrets.yaml";

      age = {
        keyFile = cfg.ageKeyFile;
        generateKey = false;
        sshKeyPaths = [ ];
      };
      gnupg.sshKeyPaths = [ ];
    };
  };
}
