# UCAS (University of Chinese Academy of Sciences) campus network environment.
{ self, config, lib, ... }:

let cfg = config.modules.services.ucasnet; in {
  options.modules.services.ucasnet = {
    enable = lib.mkEnableOption "UCAS campus network environment (Srun login & IPv6 RA guard)";
  };

  config = lib.mkIf cfg.enable {
    sops.secrets = {
      "sep-username" = { };
      "sep-password" = { };
    };

    sops.templates."bitsrun-config.yaml" = {
      restartUnits = [ "bitsrun.service" ];
      owner = config.user.name;
      content = '' #yaml
        form:
          domain: portal.ucas.ac.cn
          username: "${config.sops.placeholder."sep-username"}"
          password: "${config.sops.placeholder."sep-password"}"

        meta:
          # Fixed values from the UCAS portal page.
          "n": "200"
          type: "1"
          acid: "1" # upstream default 5 targets another school; must change
          enc: srun_bx1
          info_prefix: SRBX1
          double_stack: false # Authenticate both IPv4 and IPv6 on UCAS Srun gateway
          os: Windows 10
          name: windows

        settings:
          basic:
            https: true # portal 301s to https
            skip_cert_verify: false # GlobalSign cert for *.ucas.ac.cn; verification works
            timeout: 10
          guardian:
            enable: false # guardian reconnects on drop; false = authenticate once and exit
            duration: 60 # recheck interval (seconds)
          backoff:
            enable: true
            max_retries: 0 # 0 = unlimited
            initial_duration: 2
            max_duration: 300
            # Must be 1: upstream calls backoff.NewInstance, which does NOT
            # apply New()'s `ExponentFactor <= 0 -> 1` fallback. At 0 the wait
            # stays constant, so failed logins retry every 2s.
            exponent_factor: 1
          log:
            debug_level: false # set true when debugging
          ddns:
            enable: false # enable for DDNS on the campus intranet IP
          reality:
            enable: false # set true when login fails; simulates a browser via http://www.baidu.com
          custom_header:
            User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36
      '';
    };

    systemd.services.bitsrun = {
      description = "Srun campus network login (BitSrunLoginGo)";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      serviceConfig = {
        User = config.user.name;
        ExecStart = "${lib.getExe self.packages.bitsrun} -config ${config.sops.templates."bitsrun-config.yaml".path}";
        NoNewPrivileges = true;
        PrivateTmp = true;
      };
    };
  };
}
