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
      "https://mirrors.cernet.edu.cn/nix-channels/store"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };
}

