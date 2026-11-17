# Fleet-wide evaluation: every host must produce a toplevel derivation.
{ lib, pkgs, flake }:

let
  ok = configs:
    lib.mapAttrs (_: c: builtins.isString c.config.system.build.toplevel.drvPath) configs;

  tests.testEveryHostEvaluates = {
    expr = {
      nixos = ok flake.nixosConfigurations;
      darwin = ok flake.darwinConfigurations;
    };
    expected = {
      nixos = lib.mapAttrs (_: _: true) flake.nixosConfigurations;
      darwin = lib.mapAttrs (_: _: true) flake.darwinConfigurations;
    };
  };

  failures = lib.runTests tests;
in
pkgs.runCommand "checks-eval" {
  passthru = { inherit tests failures; };
} (
  if failures == [ ] then "touch $out" else ''
    echo ${lib.escapeShellArg (builtins.toJSON failures)} >&2
    exit 1
  ''
)
