# Darwin parity implementation of NixOS's services.syncthing interface.
{ config, lib, pkgs, ... }:

let
  cfg = config.services.syncthing;
  settingsFormat = pkgs.formats.json { };

  cleanedSettings = lib.converge
    (lib.filterAttrsRecursive (_: v: v != null && v != { }))
    cfg.settings;

  devices = lib.mapAttrsToList
    (name: dev: { inherit name; } // dev // { deviceID = dev.id; })
    (cfg.settings.devices or { });

  folders = lib.pipe (cfg.settings.folders or { }) [
    (lib.filterAttrs (_: f: f.enable or true))
    (lib.mapAttrsToList (name: f:
      { id = f.id or name; label = f.label or name; }
      // f
      // lib.optionalAttrs (f ? devices) {
        devices = map
          (d:
            if builtins.isString d then
              { deviceId = cfg.settings.devices.${d}.id; }
            else
              { deviceId = cfg.settings.devices.${d.name}.id; } // d)
          f.devices;
      }
    ))
  ];

  otherKeys = lib.subtractLists [ "devices" "folders" "defaults" "gui" ] (builtins.attrNames cleanedSettings);
  guiSettings = cleanedSettings.gui or { };
  hasInit = cleanedSettings != { } || cfg.guiPasswordFile != null;

  jq = lib.getExe pkgs.jq;
  curl = lib.getExe pkgs.curl;
  xmllint = lib.getExe' pkgs.libxml2 "xmllint";

  initScript = pkgs.writeShellScript "syncthing-init" (''
    set -euo pipefail
    umask 0077

    tmp="$(${pkgs.coreutils}/bin/mktemp -d)"
    trap '${pkgs.coreutils}/bin/rm -rf "$tmp"' EXIT

    api_key=""
    for _ in $(${pkgs.coreutils}/bin/seq 1 60); do
      if [ -r ${lib.escapeShellArg "${cfg.configDir}/config.xml"} ]; then
        api_key="$(${xmllint} --xpath 'string(configuration/gui/apikey)' \
          ${lib.escapeShellArg "${cfg.configDir}/config.xml"} 2>/dev/null || true)"
        [ -n "$api_key" ] && break
      fi
      ${pkgs.coreutils}/bin/sleep 1
    done
    [ -n "$api_key" ] || { echo "syncthing-init: timed out waiting for API key" >&2; exit 1; }

    printf 'X-API-Key: %s\n' "$api_key" > "$tmp/headers"

    api() {
      ${curl} -fsS -H "@$tmp/headers" --retry 30 --retry-delay 1 --retry-all-errors "$@"
    }

    ready=0
    for _ in $(${pkgs.coreutils}/bin/seq 1 60); do
      ct="$(api -o /dev/null -w '%header{Content-Type}' "http://${cfg.guiAddress}/rest/noauth/health" 2>/dev/null || true)"
      if printf '%s' "$ct" | ${lib.getExe pkgs.gnugrep} -qi '^application/json'; then
        ready=1
        break
      fi
      ${pkgs.coreutils}/bin/sleep 1
    done
    [ "$ready" -eq 1 ] || { echo "syncthing-init: timed out waiting for REST API" >&2; exit 1; }
  ''
  + lib.concatMapStringsSep "\n" (dev: ''
    api --json ${lib.escapeShellArg (builtins.toJSON dev)} -X POST "http://${cfg.guiAddress}/rest/config/devices"
  '') devices
  + lib.optionalString cfg.overrideDevices ''
    for id in $(api "http://${cfg.guiAddress}/rest/config/devices" | ${jq} -r --argjson keep ${lib.escapeShellArg (builtins.toJSON (map (d: d.deviceID) devices))} '[.[].deviceID] - $keep | .[] | @uri'); do
      api -X DELETE "http://${cfg.guiAddress}/rest/config/devices/$id"
    done
  ''
  + lib.concatMapStringsSep "\n" (f: ''
    api --json ${lib.escapeShellArg (builtins.toJSON (removeAttrs f [ "ignorePatterns" ]))} -X POST "http://${cfg.guiAddress}/rest/config/folders"
  '' + lib.optionalString (f.ignorePatterns or null != null) ''
    api --json ${lib.escapeShellArg (builtins.toJSON { ignore = f.ignorePatterns; })} -X POST "http://${cfg.guiAddress}/rest/db/ignores?folder=${lib.strings.escapeURL f.id}"
  '') folders
  + lib.optionalString cfg.overrideFolders ''
    for id in $(api "http://${cfg.guiAddress}/rest/config/folders" | ${jq} -r --argjson keep ${lib.escapeShellArg (builtins.toJSON (map (f: f.id) folders))} '[.[].id] - $keep | .[] | @uri'); do
      api -X DELETE "http://${cfg.guiAddress}/rest/config/folders/$id"
    done
  ''
  + lib.concatMapStringsSep "\n" (key: ''
    api --json ${lib.escapeShellArg (builtins.toJSON cleanedSettings.${key})} -X PATCH "http://${cfg.guiAddress}/rest/config/${key}"
  '') otherKeys
  + lib.optionalString (cleanedSettings ? defaults) (
    lib.concatMapStringsSep "\n" (sub:
      let method = if sub == "ignores" then "PUT" else "PATCH"; in ''
      api --json ${lib.escapeShellArg (builtins.toJSON cleanedSettings.defaults.${sub})} -X ${method} "http://${cfg.guiAddress}/rest/config/defaults/${sub}"
    '') (builtins.attrNames cleanedSettings.defaults)
  )
  + lib.optionalString (guiSettings != { } || cfg.guiPasswordFile != null) (
    if cfg.guiPasswordFile != null then ''
      ${jq} -n \
        --argjson gui ${lib.escapeShellArg (builtins.toJSON guiSettings)} \
        --rawfile pw ${lib.escapeShellArg (toString cfg.guiPasswordFile)} \
        '$gui + { password: ($pw | sub("\n$"; "")) }' \
        | api --json @- -X PATCH "http://${cfg.guiAddress}/rest/config/gui"
    '' else ''
      api --json ${lib.escapeShellArg (builtins.toJSON guiSettings)} -X PATCH "http://${cfg.guiAddress}/rest/config/gui"
    ''
  )
  + ''
    if api "http://${cfg.guiAddress}/rest/config/restart-required" | ${jq} -e .requiresRestart >/dev/null; then
      api -X POST "http://${cfg.guiAddress}/rest/system/restart"
    fi
  '');
in
{
  options.services.syncthing = with lib; with types; {
    enable = mkEnableOption "Syncthing continuous file synchronization";
    package = mkPackageOption pkgs "syncthing" { };

    user = mkOption { type = str; default = config.user.name; };
    group = mkOption { type = str; default = config.user.group; };

    dataDir = mkOption { type = path; default = config.home.dir; };
    configDir = mkOption { type = path; default = "${cfg.dataDir}/.config/syncthing"; };
    databaseDir = mkOption { type = path; default = cfg.configDir; };

    guiAddress = mkOption { type = str; default = "127.0.0.1:8384"; };
    guiPasswordFile = mkOption { type = nullOr (either path str); default = null; };

    overrideDevices = mkOption { type = bool; default = true; };
    overrideFolders = mkOption { type = bool; default = true; };
    extraFlags = mkOption { type = listOf str; default = [ ]; };

    settings = mkOption {
      type = submodule {
        freeformType = settingsFormat.type;
        options = {
          devices = mkOption { type = attrsOf (attrsOf anything); default = { }; };
          folders = mkOption { type = attrsOf (attrsOf anything); default = { }; };
        };
      };
      default = { };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.guiPasswordFile != null -> (cfg.settings.gui.user or null) != null;
        message = "services.syncthing: guiPasswordFile requires settings.gui.user to be set.";
      }
      {
        assertion = (lib.hasAttrByPath [ "gui" "password" ] cfg.settings) -> cfg.guiPasswordFile == null;
        message = "services.syncthing: use only one of settings.gui.password or guiPasswordFile.";
      }
    ];

    user.packages = [ cfg.package ];

    launchd.user.agents.syncthing = {
      environment = {
        STNORESTART = "yes";
        STNOUPGRADE = "yes";
      };

      script = ''
        ${pkgs.coreutils}/bin/mkdir -p \
          ${lib.escapeShellArg (toString cfg.configDir)} \
          ${lib.escapeShellArg (toString cfg.databaseDir)}
        ${lib.optionalString hasInit "${initScript} &"}
        exec ${lib.getExe cfg.package} ${lib.escapeShellArgs (
          [
            "serve"
            "--no-browser"
            "--gui-address=${cfg.guiAddress}"
            "--config=${toString cfg.configDir}"
            "--data=${toString cfg.databaseDir}"
          ] ++ cfg.extraFlags
        )}
      '';

      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        ProcessType = "Background";
        LowPriorityIO = true;
        StandardOutPath = "${config.home.dir}/Library/Logs/syncthing.log";
        StandardErrorPath = "${config.home.dir}/Library/Logs/syncthing.log";
      };
    };
  };
}
