let require_remote_clean host =
  let cmd = "cat \"$HOME/" ^ Impure.rel_state ^ "\" 2>/dev/null || true" in
  match String.trim (Sh.read ~stderr:`Null ["ssh"; "-n"; host; cmd]) with
  | "" -> ()
  | s when (Impure.state_of_string ~source:(host ^ ":" ^ Impure.rel_state) s).active ->
      Env.fail "impure mode is active on %s; unswap there first" host
  | _ -> ()

let deploy_host ~env host =
  Printf.printf "==> Deploying to %s...\n%!" host;
  require_remote_clean host;
  (* --diff never: auto triggers 3 extra `ssh -S none` queries *)
  Sh.run ~env ["nh"; "os"; "switch"; "-H"; host; "--diff"; "never"; "--build-host"; host; "--target-host"; host];
  (* WORKAROUND: https://github.com/nix-community/nh/pull/793 *)
  Sh.run ["ssh"; "-n"; host; "rm -f ~/result"]

let deploy hosts =
  (* Share ~/.ssh/config's ControlMaster instead of nh's per-run ControlPath.
     ssh keeps the first value per option, so a user-set NH_SSHOPTS wins. *)
  let sockets = Filename.concat Env.home ".ssh/sockets" in
  Sh.run ["mkdir"; "-p"; "-m"; "700"; sockets];
  let ours = "-o ControlPath=" ^ sockets ^ "/%r@%k:%p" in
  let opts = match Env.var "NH_SSHOPTS" with Some user -> user ^ " " ^ ours | None -> ours in
  List.iter (deploy_host ~env:["NH_SSHOPTS", opts]) hosts
