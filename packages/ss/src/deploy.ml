let deploy_host host =
  Printf.printf "==> Deploying to %s...\n%!" host;
  Impure.require_clean ~host ();
  (* --diff never: auto triggers 3 extra `ssh -S none` queries *)
  Sh.run ["nh"; "os"; "switch"; "-H"; host; "--diff"; "never"; "--build-host"; host; "--target-host"; host];
  (* WORKAROUND: https://github.com/nix-community/nh/pull/793 *)
  Sh.run ["ssh"; "-n"; host; "rm -f ~/result"]

let deploy ~repo hosts =
  List.iter (Env.require_host ~repo) hosts;
  (* Share ~/.ssh/config's ControlMaster instead of nh's per-run ControlPath *)
  let sockets = Filename.concat (Sys.getenv "HOME") ".ssh/sockets" in
  Sh.run ["mkdir"; "-p"; "-m"; "700"; sockets];
  Unix.putenv "NH_SSHOPTS" ("-o ControlPath=" ^ sockets ^ "/%r@%k:%p");
  List.iter deploy_host hosts
