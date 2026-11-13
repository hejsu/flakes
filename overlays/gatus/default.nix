final: prev:
let
  version = "5.38.0";
  src = prev.fetchFromGitHub {
    owner = "TwiN";
    repo = "gatus";
    rev = "v${version}";
    hash = "sha256-ols3YIqrrpZk+aNc5o5mCtvS2YDkqhMsIrL57YA7pLo=";
  };
  patches = [ ./links.patch ];

  frontend = prev.buildNpmPackage {
    pname = "gatus-frontend";
    inherit version src patches;
    nodejs = prev.nodejs_22;
    npmRoot = "web/app";
    npmDeps = prev.fetchNpmDeps {
      inherit src;
      sourceRoot = "source/web/app";
      hash = "sha256-1QxHnU4J7A823KUVVBY28Xv2LjBIJbL06ZHhcIROwKU=";
    };

    buildPhase = ''
      runHook preBuild
      cd web/app
      npm run build
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      cp -R ../static "$out"
      runHook postInstall
    '';
  };
in {
  gatus = prev.gatus.overrideAttrs (old: {
    inherit version src patches;
    vendorHash = "sha256-/IfnwjAtBK0qlGQz7uqGzQ0nw7emW7jdptEMYoTMSoQ=";

    preBuild = ''
      chmod -R u+w web/static
      cp -R ${frontend}/. web/static/
    '';

    passthru = old.passthru // { inherit frontend; };
  });
}
