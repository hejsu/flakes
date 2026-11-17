{ lib
, ocamlPackages
, makeWrapper
, age
, git
, openssh
, coreutils
, gnused
}:

ocamlPackages.buildDunePackage {
  pname = "ss";
  version = "0.1.0";
  duneVersion = "3";
  src = lib.cleanSourceWith {
    src = ./.;
    filter = path: type:
      lib.cleanSourceFilter path type
      && !(builtins.elem (baseNameOf path) [ "_build" ".direnv" ]);
  };

  buildInputs = [ ocamlPackages.cmdliner ocamlPackages.yojson ocamlPackages.spawn ];
  nativeBuildInputs = [ makeWrapper ];
  checkInputs = [ ocamlPackages.alcotest ];
  nativeCheckInputs = [ age git coreutils gnused ];
  doCheck = true;

  postInstall = ''
    wrapProgram "$out/bin/ss" \
      --suffix PATH : ${lib.makeBinPath [ age git openssh coreutils ]}
  '';

  meta = {
    description = "Dotfiles management helper";
    license = lib.licenses.mit;
    mainProgram = "ss";
    platforms = lib.platforms.unix;
  };
}
