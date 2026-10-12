# UCAS（中国科学院大学）深澜（srun）校园网自动认证。
{ ss, config, lib, ... }:

let cfg = config.modules.services.ucasrun; in {
  options.modules.services.ucasrun = {
    enable = lib.mkEnableOption "UCAS campus network login (BitSrunLoginGo)";
  };

  config = lib.mkIf cfg.enable {
    sops.secrets = {
      "sep-username" = { };
      "sep-password" = { };
    };

    sops.templates."bitsrun-config.yaml" = {
      restartUnits = [ "bitsrun.service" ];
      owner = config.user.name;
      content = ''
        form:
          domain: portal.ucas.ac.cn
          username: "${config.sops.placeholder."sep-username"}"
          password: "${config.sops.placeholder."sep-password"}"

        meta:
          # 以下都是 UCAS 门户页里带出来的固定值
          "n": "200"
          type: "1"
          acid: "1" # 上游默认值 5 是别的学校的，必须改
          enc: srun_bx1
          info_prefix: SRBX1
          double_stack: false # UCAS 门户 DoubleStackPC = false
          os: Windows 10
          name: windows

        settings:
          basic:
            https: true # 门户已 301 到 https
            skip_cert_verify: false # 证书由 GlobalSign 签发给 *.ucas.ac.cn，可正常校验
            timeout: 10
          guardian:
            enable: false # 常驻守护，掉线自动重连；false 则只认证一次就退出
            duration: 60 # 复查间隔（秒）
          backoff:
            enable: true
            max_retries: 0 # 0 = 无限重试
            initial_duration: 2
            max_duration: 300
            # 必须写 1：上游走的是 backoff.NewInstance，它**不**套用 New() 里的
            # `ExponentFactor <= 0 -> 1` 兜底。留空 = 0 = `(wait + 0) << 0 + 0` = wait 恒定，
            # 退避就退不起来了，登录失败会一直 2 秒一轮。
            exponent_factor: 1
          log:
            debug_level: false # 排查问题时改 true
          ddns:
            enable: false # 需要校园网内网 IP 的 DDNS 时再开
          reality:
            enable: false # 登录出问题时设为 true，会从 http://www.baidu.com 模拟浏览器进登录页
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
        ExecStart = "${lib.getExe ss.packages.bitsrun} -config ${config.sops.templates."bitsrun-config.yaml".path}";
        NoNewPrivileges = true;
        PrivateTmp = true;
      };
    };
  };
}
