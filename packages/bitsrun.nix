# BitSrunLoginGo (bitsrun) —— 深澜（srun）校园网认证客户端。
{ lib
, buildGoModule
, fetchFromGitHub
, self
}:

buildGoModule rec {
  pname = "bitsrun";
  version = "1.6.8";

  src = fetchFromGitHub {
    owner = "Mmx233";
    repo = "BitSrunLoginGo";
    rev = "v${version}";
    hash = "sha256-V+nLRMH2cAerTAwSWSeUgJHujSnvEpTxOTid0QKCfVI=";
  };

  subPackages = [ "cmd/bitsrun" ];

  proxyVendor = true;
  vendorHash = "sha256-yYe02N6TEJ0FWjyLmBRO92YMGnZ/FkASrV2obOdtOBw=";
  env.GOPROXY = "https://goproxy.cn,direct";

  ldflags = [ "-s" "-w" ];

  meta = {
    description = "Srun campus network login client";
    homepage = "https://github.com/Mmx233/BitSrunLoginGo";
    mainProgram = "bitsrun";
    license = lib.licenses.agpl3Only;
    platforms = lib.platforms.unix;
  };
}
