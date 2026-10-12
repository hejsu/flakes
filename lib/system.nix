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

      autoModules = modules;

      mkPkgs = system: import nixpkgs {
        inherit system;
        overlays = overlayList;
        config.allowUnfree = true;
      };
      pkgsBySystem = genAttrs systems mkPkgs;
      pkgsFor = system:
        pkgsBySystem.${system} or (throw "Host system '${system}' is not in the supported 'systems' list in flake.nix: ${toJSON systems}");

      mkSS = platformKey: system: {
        modules = mapAttrs (_: i: i.${platformKey} or { }) inputs;
        sourceDir = self;
        configDir = self + /config;
        # This flake's own packages, for the host's system, so modules can
        # reach them as `ss.packages.<name>` without threading `self` around.
        packages = self.packages.${system};
        keys = import ./keys.nix;
      };

      getSystem = path:
        let fn = import path; in
        (if isFunction fn then fn (mapAttrs (_: _: { }) (functionArgs fn)) else fn).system;

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

      buildHost = platform: hostName: hostPath:
        let
          specialArgs = {
            inherit inputs self lib;
            ss = mkSS platform.moduleKey (getSystem hostPath);
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
            extraModules = (attrValues autoModules) ++ platform.extraModules;
          };
        };

      # callPackage 先行：平台过滤读的是构建出来的 derivation 上的 meta，
      # 不是包函数本身。explicitArgs 由 callPackage 原样透传，所以每个包文件
      # 都得声明 `self`（或写 `...`），哪怕自己用不到。
      withPkgs = system: packageAttrs:
        let pkgs = pkgsFor system; in
        filterAttrs (_: v: !(v ? meta.platforms) || elem system v.meta.platforms)
          (mapAttrs
            (_: p: pkgs.callPackage p { self = self.packages.${system}; })
            packageAttrs);

      mkConfigs = p: mapAttrs (buildHost p) (filterAttrs (_: path: p.match (getSystem path)) hosts);
      exportedModules = autoModules // { default = { imports = attrValues autoModules; }; };
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
