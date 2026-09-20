{ lib }:

with lib;
let
  isModuleFile = n: v:
    v == "regular"
    && n != "default.nix"
    && hasSuffix ".nix" n;

in {
  # 统一的模块目录递归扫描器（modules, packages, overlays）
  mapModules = dir: fn:
    let
      walk = prefix: path:
        concatMapAttrs (n: v:
          let
            sub = path + "/${n}";
            key = if prefix == "" then n else "${prefix}.${n}";
          in
          if hasPrefix "." n || hasPrefix "_" n then 
            {}
          else if v == "directory" then
            if pathExists (sub + "/default.nix")
            then { ${key} = fn sub; }
            else walk key sub
          else if isModuleFile n v then
            { ${removeSuffix ".nix" key} = fn sub; }
          else 
            {}
        ) (readDir path);
    in
      if pathExists dir then walk "" dir else {};
}
