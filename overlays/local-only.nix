final: prev:
let
  localOnly = [ "etc" "launchd" "hjem-activate" ];

  localize = drv:
    drv.overrideAttrs (_: {
      allowSubstitutes = false;
      preferLocalBuild = true;
    });
in {
  runCommand = name: env: cmd:
    let drv = prev.runCommand name env cmd; in
      if builtins.elem name localOnly then
        localize drv
      else
        drv;

  writeShellApplication = args:
    let drv = prev.writeShellApplication args; in
      if builtins.elem (args.name or "") localOnly then
        localize drv
      else
        drv;
}
