# Service capability checks: forwarding, withdrawal, conflict detection, and
# every real host still evaluating.
{ lib, pkgs, flake }:

let
  system = pkgs.stdenv.hostPlatform.system;
  nixpkgs = flake.inputs.nixpkgs;

  # A fixture service: implements the interface without pulling in sops/OCI.
  fixture = name: { config, lib, services, ... }: {
    options.modules.services.${name} = {
      enable = lib.mkEnableOption name;
      ingress = lib.mkOption { type = services.ingressType; default = { }; };
    };

    config = lib.mkIf config.modules.services.${name}.enable {
      modules.ingress.tailnet = config.modules.services.${name}.ingress.tailnet;
      modules.ingress.caddy = config.modules.services.${name}.ingress.caddy;
    };
  };

  eval = extraModules:
    (nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ../modules/services/lib.nix
        (fixture "alpha")
        (fixture "beta")
        {
          boot.isContainer = true;
          system.stateVersion = "26.11";
        }
      ] ++ extraModules;
    }).config;

  enabled = eval [{
    modules.services.alpha = {
      enable = true;
      ingress.tailnet.alpha.endpoints."tcp:80" = "tcp://127.0.0.1:1111";
      ingress.caddy."alpha.example.com".extraConfig = "respond alpha";
    };
  }];

  disabled = eval [{
    modules.services.alpha = {
      enable = lib.mkForce false;
      ingress.tailnet.alpha.endpoints."tcp:80" = "tcp://127.0.0.1:1111";
    };
  }];

  conflicting = builtins.tryEval (
    (eval [{
      modules.services.alpha = {
        enable = true;
        ingress.tailnet.same.endpoints."tcp:80" = "tcp://127.0.0.1:1111";
      };
      modules.services.beta = {
        enable = true;
        ingress.tailnet.same.endpoints."tcp:80" = "tcp://127.0.0.1:2222";
      };
    }]).services.tailscale.serve.services.same.endpoints."tcp:80"
  );

  tests = {
    testIngressForwarded = {
      expr = enabled.services.tailscale.serve.services.alpha.endpoints."tcp:80";
      expected = "tcp://127.0.0.1:1111";
    };

    testCaddyForwarded = {
      expr = enabled.services.caddy.virtualHosts."alpha.example.com".extraConfig;
      expected = "respond alpha";
    };

    testBackendsEnabled = {
      expr = enabled.services.tailscale.serve.enable && enabled.services.caddy.enable;
      expected = true;
    };

    testDisabledWithdrawsIngress = {
      expr = disabled.services.tailscale.serve.services ? alpha;
      expected = false;
    };

    testConflictingDestinationsRejected = {
      expr = conflicting.success;
      expected = false;
    };

    # Forces every host's toplevel drvPath: catches assertions, type errors and
    # unbound variables across the real configurations without building them.
    testEveryHostEvaluates = {
      expr = {
        nixos = lib.mapAttrs
          (_: c: builtins.isString c.config.system.build.toplevel.drvPath)
          flake.nixosConfigurations;
        darwin = lib.mapAttrs
          (_: c: builtins.isString c.config.system.build.toplevel.drvPath)
          flake.darwinConfigurations;
      };
      expected = {
        nixos = lib.mapAttrs (_: _: true) flake.nixosConfigurations;
        darwin = lib.mapAttrs (_: _: true) flake.darwinConfigurations;
      };
    };
  };

  failures = lib.runTests tests;
in
pkgs.runCommand "checks-services"
  {
    passthru = { inherit tests failures; };
    # These are NixOS evaluations; do not offer them on Darwin.
    meta.platforms = [ "x86_64-linux" ];
  }
  (
    if failures == [ ] then
      "touch $out"
    else ''
      echo "services checks failed:" >&2
      echo ${lib.escapeShellArg (builtins.toJSON failures)} >&2
      exit 1
    ''
  )
