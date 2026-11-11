# profiles/networks/tyo.nix --- Tokyo / Overseas high-speed network environment
{ ... }: {
  time.timeZone = "Asia/Tokyo";

  location = {
    latitude = 35.6762;
    longitude = 139.6503;
  };

  # Japan local NTP sources
  networking.timeServers = [
    "ntp.nict.jp"
    "time.cloudflare.com"
  ];

  # Overseas: personal cache first, then Numtide and the default official cache.
  nix.settings = {
    substituters = [
      "https://suspen.cachix.org?priority=20"
      "https://cache.numtide.com"
    ];
    trusted-public-keys = [
      "suspen.cachix.org-1:RU+fX6MttiKajapdYBEOEbq/nuQGl5Qb8BTPTkLs4TU="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
  };
}
