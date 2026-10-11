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

      mkSS = platformKey: {
        modules = mapAttrs (_: i: i.${platformKey} or { }) inputs;
        sourceDir = self;
        configDir = self + /config;
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
            extraModules = (attrValues autoModules) ++ platform.extraModules;
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
