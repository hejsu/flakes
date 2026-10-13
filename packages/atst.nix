{ lib
, stdenvNoCC
, fetchurl
, _7zz
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "atst";
  version = "0.4.0";

  __structuredAttrs = true;
  strictDeps = true;

  src = fetchurl {
    url = "https://github.com/itaober/atst/releases/download/v${finalAttrs.version}/atst.dmg";
    hash = "sha256-sjvq81YeGKQvgvufYeu2WAiyg/lAaEZHaoP7fJaacb0=";
  };

  nativeBuildInputs = [ _7zz ];
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/Applications"
    cp -R */atst.app "$out/Applications/atst.app"

    runHook postInstall
  '';

  dontFixup = true;

  meta = {
    homepage = "https://github.com/itaober/atst";
    description = "a(i)-text-select-translate — a tiny menu-bar translator for macOS";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = lib.platforms.darwin;
    mainDarwinApp = "atst.app";
  };
})
