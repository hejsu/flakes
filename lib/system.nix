{ lib }:

with builtins;
with lib;
rec {
  # resolveProfiles :: attrs -> attrs -> listOf path
  resolveProfiles = profiles: hostProfiles:
    concatLists (mapAttrsToList
      (k: v:
        if v == null then
          [ ]
        else
          optional (profiles ? "${k}.${v}") profiles."${k}.${v}"
      )
      hostProfiles);

  mkHostModules =
    { host
    , hostName
    , pkgs
    , profiles ? { }
    , extraModules ? [ ]
    }: [
      {
        nixpkgs.pkgs = pkgs;
        networking.hostName = mkDefault hostName;
      }
    ]
    ++ (resolveProfiles profiles host.profiles)
    ++ host.includes
    ++ [
      host.hardware
      host.settings
      { inherit (host) modules; }
    ]
    ++ extraModules;

  # Flake 顶层构建器
  mkFlake = inputs@{ self, nixpkgs, ... }:
    { hosts ? { }
    , systems ? [ "aarch64-darwin" "x86_64-linux" ]
    , modules ? { }
    , profiles ? { }
    , overlays ? { }
    , packages ? { }
    , ...
    }:
    let
      overlayList = attrValues overlays;

      autoModules = modules;

      # 全局架构单例 Nixpkgs 缓存（大幅降低重复求值开销）
      mkPkgs = system: import nixpkgs {
        inherit system;
        overlays = overlayList;
        config.allowUnfree = true;
      };
      pkgsBySystem = genAttrs systems mkPkgs;
      pkgsFor = system:
        pkgsBySystem.${system} or (throw "Host system '${system}' is not in the supported 'systems' list in flake.nix: ${toJSON systems}");

      # 上下文生成器
      mkSS = platformKey: {
        modules = mapAttrs (_: i: i.${platformKey} or { }) inputs;
        sourceDir = self;
        configDir = self + /config;
        keys = import ./keys.nix;
      };

      # 通用系统架构嗅探器：通过反射函数形参动态补全占位符，微秒级惰性直读 system
      getSystem = path:
        let fn = import path; in
        (if isFunction fn then fn (mapAttrs (_: _: { }) (functionArgs fn)) else fn).system;

      platforms = {
        darwin = {
          builder = inputs.darwin.lib.darwinSystem;
          moduleKey = "darwinModules";
          match = s: hasSuffix "-darwin" s;
        };
        nixos = {
          builder = inputs.nixpkgs.lib.nixosSystem;
          moduleKey = "nixosModules";
          match = s: hasSuffix "-linux" s;
        };
      };

      buildHost = platform: hostName: hostPath:
        let
          specialArgs = {
            inherit inputs self lib;
            ss = mkSS platform.moduleKey;
          };
          host = evalHost {
            module = hostPath;
            inherit specialArgs;
          };
        in
        platform.builder {
          inherit specialArgs;
          system = host.system;
          modules = mkHostModules {
            inherit host hostName profiles;
            pkgs = pkgsFor host.system;
            extraModules = attrValues autoModules;
          };
        };

      mkConfigs = p: mapAttrs (buildHost p) (filterAttrs (_: path: p.match (getSystem path)) hosts);
      exportedModules = autoModules // { default = { imports = attrValues autoModules; }; };
    in
    {
      inherit lib overlays;

      darwinModules = exportedModules;
      nixosModules = exportedModules;

      darwinConfigurations = mkConfigs platforms.darwin;
      nixosConfigurations = mkConfigs platforms.nixos;

      packages = genAttrs systems (system:
        mapAttrs (_: p: (pkgsFor system).callPackage p { }) packages
      );

      formatter = genAttrs systems (system:
        (pkgsFor system).nixpkgs-fmt
      );
    };
}
