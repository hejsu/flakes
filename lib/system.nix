{ lib }:

with builtins;
with lib;
rec {
  # resolveProfiles :: attrs -> attrs -> listOf path
  resolveProfiles = profiles: hostProfiles:
    concatLists (mapAttrsToList (k: v:
      if v == null then 
        []
      else 
        optional (profiles ? "${k}.${v}") profiles."${k}.${v}"
    ) hostProfiles);

  mkHostModules = {
    host
  , hostName
  , pkgs
  , profiles ? {}
  , extraModules ? []
  }: [
    {
      nixpkgs.pkgs = pkgs;
      networking.hostName = mkDefault hostName;
    }
  ]
  ++ (resolveProfiles profiles host.profiles)
  ++ [
    host.hardware
    host.setting
    { inherit (host) modules; }
  ]
  ++ extraModules;

  # Flake 顶层构建器
  mkFlake = inputs@{ self, nixpkgs, ... }:
    { hosts ? {}
    , systems ? [ "aarch64-darwin" ]
    , modules ? {}
    , profiles ? {}
    , overlays ? {}
    , packages ? {}
    , ...
    }:
    let
      overlayList = attrValues overlays;
      moduleList  = attrValues modules;

      # 全局架构单例 Nixpkgs 缓存（大幅降低重复求值开销）
      mkPkgs = system: import nixpkgs {
        inherit system;
        overlays = overlayList;
        config.allowUnfree = true;
      };
      pkgsFor = system: (genAttrs systems mkPkgs).${system};

      platforms = {
        darwin = {
          builder   = inputs.darwin.lib.darwinSystem;
          moduleKey = "darwinModules";
          match     = h: hasSuffix "-darwin" h.system;
        };
        nixos = {
          builder   = inputs.nixpkgs.lib.nixosSystem;
          moduleKey = "nixosModules";
          match     = h: hasSuffix "-linux" h.system;
        };
      };

      buildHost = platform: hostName: host:
        platform.builder {
          system = host.system;
          modules = mkHostModules {
            inherit host hostName profiles;
            pkgs = pkgsFor host.system;
            extraModules = moduleList;
          };
          specialArgs = {
            inherit inputs self lib;
            ss = {
              modules   = mapAttrs (_: i: i.${platform.moduleKey} or {}) inputs;
              sourceDir = self;
              configDir = self + /config;
              keys      = import ./keys.nix;
            };
          };
        };

      mkConfigs = p: mapAttrs (buildHost p) (filterAttrs (_: p.match) hosts);
      exportedModules = modules // { default = { imports = moduleList; }; };
    in {
      inherit lib overlays;

      darwinModules = exportedModules;
      nixosModules  = exportedModules;

      darwinConfigurations = mkConfigs platforms.darwin;
      nixosConfigurations  = mkConfigs platforms.nixos;

      packages = genAttrs systems (system:
        mapAttrs (_: p: (pkgsFor system).callPackage p {}) packages
      );

      formatter = genAttrs systems (system:
        (pkgsFor system).nixfmt-rfc-style
      );
    };
}
