# profiles/networks/pek.nix --- Beijing / Mainland China network environment
{ ... }: {
  time.timeZone = "Asia/Shanghai";

  location = {
    latitude = 39.9042;
    longitude = 116.4074;
  };

  # Domestic NTP sources
  networking.timeServers = [
    "ntp.aliyun.com"
    "ntp.tencent.com"
  ];

  # Fast domestic mirrors
  nix.settings = {
    substituters = [
      "https://suspen.cachix.org?priority=20"
      "https://avoidtuna.mirrors.cernet.edu.cn/nix-channels/store"
      "https://cache.numtide.com"
    ];
    trusted-public-keys = [
      "suspen.cachix.org-1:RU+fX6MttiKajapdYBEOEbq/nuQGl5Qb8BTPTkLs4TU="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
  };
}
