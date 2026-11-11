{ config, ... }: {
  sops.secrets = {
    "restic-password" = { };
    "s3-cstnet-ak" = { };
    "s3-cstnet-sk" = { };
  };

  sops.templates."restic.env" = {
    content = ''
      AWS_ACCESS_KEY_ID="${config.sops.placeholder."s3-cstnet-ak"}"
      AWS_SECRET_ACCESS_KEY="${config.sops.placeholder."s3-cstnet-sk"}"
    '';
  };

  services.restic.backups.cpa = {
    initialize = true;
    repository = "s3:https://s3.cstcloud.cn/echo-restic";
    environmentFile = config.sops.templates."restic.env".path;
    passwordFile = config.sops.secrets."restic-password".path;
    extraOptions = [ "s3.bucket-lookup=path" ];

    paths = [
      "/var/lib/private/cliproxyapi"
      "/var/lib/private/cpa-usage-keeper"
    ];

    exclude = [
      "/var/lib/private/cliproxyapi/auth/logs"
      "/var/lib/private/cpa-usage-keeper/logs"
    ];

    pruneOpts = [ "--keep-daily 30" "--keep-weekly 12" "--keep-monthly 12" ];
    checkOpts = [ "--read-data" ];
  };
}
