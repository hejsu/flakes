{ lib
, buildGoModule
, fetchFromGitHub
, cacert
, makeWrapper
, go_1_26 ? null
, go
}:

let
  version = "latest-v7.3.2";
  rev = "7fa443dc8bf8ca2f1ffd81c2472deb31b097b697";
  src = fetchFromGitHub {
    owner = "router-for-me";
    repo = "CLIProxyAPI";
    inherit rev;
    hash = "sha256-AgyWs2xkgkUqKKOSY1dAaN9BdEqo73BKmPpYMzSxVds=";
  };
in
buildGoModule {
  pname = "cli-proxy-api";
  inherit version src;

  vendorHash = "sha256-CrDp7MOr+AwJUhTovklXx3F1yaktQlvD7VYhYSY6VvY=";
  subPackages = [ "cmd/server" ];

  env.CGO_ENABLED = 0;

  ldflags = [
    "-s"
    "-w"
    "-X"
    "main.Version=${version}"
    "-X"
    "main.Commit=${rev}"
    "-X"
    "main.BuildDate=1970-01-01"
  ];

  nativeBuildInputs = [ makeWrapper ];

  go = if go_1_26 != null then go_1_26 else go;

  postInstall = ''
    if [ -e "$out/bin/server" ]; then
      mv "$out/bin/server" "$out/bin/cli-proxy-api"
    elif [ -e "$out/bin/CLIProxyAPI" ]; then
      mv "$out/bin/CLIProxyAPI" "$out/bin/cli-proxy-api"
    fi

    wrapProgram "$out/bin/cli-proxy-api" \
      --set-default SSL_CERT_FILE "${cacert}/etc/ssl/certs/ca-bundle.crt"
  '';

  meta = with lib; {
    description = "OpenAI/Gemini/Claude/Codex compatible proxy API server for CLI tools";
    homepage = "https://github.com/router-for-me/CLIProxyAPI";
    license = licenses.mit;
    mainProgram = "cli-proxy-api";
    platforms = platforms.linux ++ platforms.darwin;
  };
}

