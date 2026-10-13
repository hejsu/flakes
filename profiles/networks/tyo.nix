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

  # Overseas official CDN & community cache
  nix.settings = {
    substituters = [
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };
}

