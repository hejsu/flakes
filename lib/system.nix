{ lib }:

with builtins;
with lib;
rec {
  # resolveProfiles :: attrs -> attrs -> listOf path
  # Resolves profile selectors into module paths. Unknown profiles fail fast with an informative error.
  resolveProfiles = profiles: hostProfiles:
    concatMap
      (k:
        let vals = filter (v: v != null && v != "") (toList hostProfiles.${k}); in
        map (val:
          let key = "${k}.${val}"; in
            profiles.${key} or (throw ''

            [Dotfiles Error] Unknown profile '${key}' referenced in host configuration!
            Available profiles:
              ${concatStringsSep "\n  " (map (n: "- " + n) (attrNames profiles))}
          ''))
        vals)
      (attrNames hostProfiles);

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

      mkPkgs = system: import nixpkgs {
        inherit system;
        overlays = overlayList;
        config.allowUnfree = true;
      };
      pkgsBySystem = genAttrs systems mkPkgs;
      pkgsFor = system:
        pkgsBySystem.${system} or (throw "Host system '${system}' is not in the supported 'systems' list in flake.nix: ${toJSON systems}");

      # A flake as one system sees it: packages.${system}.foo -> packages.foo.
      forSystem = system: flake:
        flake // mapAttrs (_: v: v.${system} or { })
          (filterAttrs (n: _: elem n [ "packages" "legacyPackages" "devShells" "apps" "checks" "formatter" ]) flake);

      # The enriched `self` every module and host receives
      mkSelf = platform: system: hostPath:
        forSystem system self // {
          inherit lib;
          hostDir = dirOf hostPath;
          sourceDir = self;
          configDir = self + /config;
          keys = import ./keys.nix;
          # 递归将所有 inputs 按当前主机的 system 扁平化，模块可直接使用 self.inputs.<flake>.packages.<pkg>
          inputs = mapAttrs (_: forSystem system) inputs;
          # 提取外部 inputs 中当前平台对应的模块（darwinModules 或 nixosModules）
          modules = mapAttrs (_: i: i.${platform.moduleKey} or { }) inputs;
        };

      getSystem = path:
        let fn = import path; in
        (if isFunction fn then fn (mapAttrs (_: _: { }) (functionArgs fn)) else fn).system;

      hostsWithSystem = mapAttrs (_: path: { inherit path; system = getSystem path; }) hosts;

      platforms = {
        darwin = {
          builder = inputs.darwin.lib.darwinSystem;
          moduleKey = "darwinModules";
          match = s: hasSuffix "-darwin" s;
          extraModules = [
            ../modules/_darwin
            { _module.freeformType = lib.types.attrsOf lib.types.anything; }
          ];
        };
        nixos = {
          builder = inputs.nixpkgs.lib.nixosSystem;
          moduleKey = "nixosModules";
          match = s: hasSuffix "-linux" s;
          extraModules = [ ];
        };
      };

      buildHost = platform: hostName: { path, system }:
        let
          self' = mkSelf platform system path;
          specialArgs = {
            inherit lib;
            self = self';
          };
          host = evalHost {
            module = path;
            inherit specialArgs;
          };
        in
        platform.builder {
          inherit specialArgs system;
          modules = mkHostModules {
            inherit host hostName profiles;
            pkgs = pkgsFor system;
            extraModules = (attrValues modules) ++ platform.extraModules;
          };
        };

      # callPackage 先行：平台过滤读的是构建出来的 derivation 上的 meta，
      # 不是包函数本身。
      withPkgs = system: packageAttrs:
        let pkgs = pkgsFor system; in
        filterAttrs (_: v: !(v ? meta.platforms) || elem system v.meta.platforms)
          (mapAttrs
            (_: p: pkgs.callPackage p { })
            packageAttrs);

      mkConfigs = p:
        mapAttrs (buildHost p)
          (filterAttrs (_: { system, ... }: p.match system) hostsWithSystem);

      exportedModules = modules // { default = { imports = attrValues modules; }; };
    in
    {
      inherit lib overlays;

      darwinModules = exportedModules;
      nixosModules = exportedModules;

      darwinConfigurations = mkConfigs platforms.darwin;
      nixosConfigurations = mkConfigs platforms.nixos;

      packages = genAttrs systems (system: withPkgs system packages);

      formatter = genAttrs systems (system:
        (pkgsFor system).nixpkgs-fmt
      );
    };
}
