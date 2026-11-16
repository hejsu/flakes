open Cmdliner
open Cmdliner.Term.Syntax
open Ss_lib

let unit_cmd name ~doc fn =
  let info = Cmd.info name ~doc in
  Cmd.make info (let+ () = Term.const () in fn ())

let sync_cmd =
  let info = Cmd.info "sync" ~doc:"Rebuild and activate this host" in
  let dry = Arg.(value & flag & info ["n"; "dry"] ~doc:"Only print actions.") in
  let ask = Arg.(value & flag & info ["a"; "ask"] ~doc:"Ask for confirmation.") in
  let verbose = Arg.(value & flag & info ["v"; "verbose"] ~doc:"Increase verbosity.") in
  let no_nom = Arg.(value & flag & info ["no-nom"] ~doc:"Do not use nix-output-monitor.") in
  Cmd.make info (
    let+ dry and+ ask and+ verbose and+ no_nom in
    Sync.sync ~dry ~ask ~verbose ~no_nom ()
  )

let rollback_cmd =
  let info = Cmd.info "rollback" ~doc:"Roll back to a previous system generation" in
  let gen = Arg.(value & pos 0 (some int) None & info [] ~docv:"GEN" ~doc:"Target generation number.") in
  Cmd.make info (
    let+ gen in
    Sync.rollback ?gen ()
  )

let gc_cmd =
  let info = Cmd.info "gc" ~doc:"Clean profiles and optimise the store" in
  let user = Arg.(value & flag & info ["u"; "user"] ~doc:"Only this user's profiles.") in
  let keep = Arg.(value & opt int 3 & info ["k"; "keep"] ~docv:"INT" ~doc:"Minimum number of generations to keep.") in
  let keep_since =
    Arg.(value & opt (some string) None & info ["K"; "keep-since"] ~docv:"DURATION"
           ~doc:"Keep generations and gcroots newer than $(docv) (e.g. 14d).")
  in
  let dry = Arg.(value & flag & info ["n"; "dry"] ~doc:"Only print actions.") in
  let ask = Arg.(value & flag & info ["a"; "ask"] ~doc:"Ask for confirmation.") in
  Cmd.make info (
    let+ user and+ keep and+ keep_since and+ dry and+ ask in
    Gc.gc ~user ~keep ~keep_since ~dry ~ask
  )

let pull ~repo = function
  | `All -> Sh.run ["nix"; "flake"; "update"; "--flake"; repo]
  | `Inputs ins ->
      List.iter Env.require_input ins;
      Sh.run (["nix"; "flake"; "update"; "--flake"; repo] @ ins)

let pull_cmd ~repo =
  let info = Cmd.info "pull" ~doc:"Update flake inputs" in
  let all = Arg.(value & flag & info ["a"; "all"] ~doc:"Update all flake inputs.") in
  let inputs = Arg.(value & pos_all string [] & info [] ~docv:"INPUT" ~doc:"Flake input(s) to update.") in
  let target =
    Term.ret (
      let+ all and+ inputs in
      match all, inputs with
      | true, [] -> `Ok `All
      | false, (_ :: _ as ins) -> `Ok (`Inputs ins)
      | false, [] -> `Error (true, "pass INPUT... or --all")
      | true, _ :: _ -> `Error (true, "--all cannot be combined with INPUT...")
    )
  in
  Cmd.make info (
    let+ target in
    pull ~repo target
  )

let gens () =
  if Env.is_darwin () then Sh.run ["sudo"; "darwin-rebuild"; "--list-generations"]
  else Sh.run ["nh"; "os"; "info"]

let repl ~repo () =
  Sh.run ["nix"; "repl"; "--extra-experimental-features"; "flakes repl-flake"; "--impure"; repo]

let path_cmd ~repo =
  let info = Cmd.info "path" ~doc:"Print a path inside the repo" in
  let area_doc = Printf.sprintf "Repo area (%s)." (Arg.doc_alts_enum Path.areas) in
  let area = Arg.(value & pos 0 (enum Path.areas) Path.Repo & info [] ~docv:"AREA" ~doc:area_doc) in
  let rest = Arg.(value & pos_right 0 string [] & info [] ~docv:"SUBPATH" ~doc:"Optional subpath segment(s).") in
  Cmd.make info (
    let+ area and+ rest in
    print_endline (Path.resolve ~repo ~area rest)
  )

let deploy_cmd ~repo =
  let info = Cmd.info "deploy" ~doc:"Rebuild and activate configuration on remote host(s)" in
  let hosts = Arg.(non_empty & pos_all string [] & info [] ~docv:"HOST" ~doc:"Target host(s).") in
  Cmd.make info (
    let+ hosts in
    Deploy.deploy ~repo hosts
  )

let enroll_cmd ~repo =
  let info = Cmd.info "enroll" ~doc:"Provision the sops age machine key on a host" in
  let host = Arg.(required & pos 0 (some string) None & info [] ~docv:"HOST" ~doc:"Target host.") in
  Cmd.make info (
    let+ host in
    Enroll.enroll ~repo host
  )

let root_cmd ~repo =
  let info = Cmd.info "ss" ~doc:"Dotfiles management helper" in
  let default = let+ () = Term.const () in Sync.sync () in
  Cmd.group info ~default [
    sync_cmd;
    rollback_cmd;
    unit_cmd "swap" ~doc:"Swap store links for mutable copies" Impure.swap;
    unit_cmd "unswap" ~doc:"Restore store links (re-runs the hjem agent)" Impure.unswap;
    unit_cmd "gens" ~doc:"List system generations" gens;
    gc_cmd;
    pull_cmd ~repo;
    unit_cmd "repl" ~doc:"Open a nix repl with the flake preloaded" (repl ~repo);
    path_cmd ~repo;
    deploy_cmd ~repo;
    enroll_cmd ~repo;
  ]

let () =
  try
    let repo = Env.init_repo () in
    exit (Cmd.eval ~catch:false (root_cmd ~repo))
  with Failure msg ->
    Printf.eprintf "ss: %s\n" msg;
    exit 1
