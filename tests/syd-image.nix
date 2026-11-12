# Static image isolation and dependency checks, not build/boot acceptance tests.
{ lib, pkgs, flake }:

let
  daily = flake.nixosConfigurations.syd.config;
  image = daily.system.build.images.vhdx;
  cfg = image.passthru.config;
  init = cfg.systemd.services.register-nix-paths;

  tests = {
    testNoRuntimeInitializer = {
      expr = daily.systemd.services ? register-nix-paths;
      expected = false;
    };
    testHostMountsPreserved = {
      expr = cfg.fileSystems;
      expected = daily.fileSystems;
    };
    testImageAssertions = {
      expr = builtins.all (a: a.assertion) (cfg.assertions ++ cfg.image.repart.assertions);
      expected = true;
    };
    testNoRuntimeRepartitioning = {
      expr = cfg.systemd.repart.enable || cfg.boot.initrd.systemd.repart.enable;
      expected = false;
    };
    testImageEvaluates = {
      expr = builtins.isString image.drvPath;
      expected = true;
    };
    testGcGuard = {
      expr = builtins.elem "register-nix-paths.service" cfg.systemd.services.nix-gc.requires
        && builtins.elem "nix-gc.service" init.before;
      expected = true;
    };
    testDaemonGuard = {
      expr = builtins.elem "register-nix-paths.service" cfg.systemd.sockets.nix-daemon.requires
        && builtins.elem "register-nix-paths.service" cfg.systemd.services.nix-daemon.requires;
      expected = true;
    };
  };

  failures = lib.runTests tests;
in
pkgs.runCommand "checks-syd-image" {
  passthru = { inherit tests failures; };
  meta.platforms = [ "x86_64-linux" ];
} (
  if failures == [ ] then "touch $out" else ''
    echo ${lib.escapeShellArg (builtins.toJSON failures)} >&2
    exit 1
  ''
)
