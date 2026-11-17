open Cmdliner
open Cmdliner.Term.Syntax
open Ss_lib

let guard fn =
  try Ok (fn ()) with
  | Env.Error msg -> Error msg
  | Unix.Unix_error (e, fn, arg) ->
      Error (Printf.sprintf "%s%s: %s" fn (if arg = "" then "" else " " ^ arg) (Unix.error_message e))
  | Sys_error msg when String.ends_with ~suffix:"Broken pipe" msg ->
      exit 141 (* reader went away: quiet, like dying of SIGPIPE *)
  | Sys_error msg -> Error msg
  | Sys.Break -> prerr_newline (); exit 130

let unit_cmd name ~doc fn =
  Cmd.make (Cmd.info name ~doc) (let+ () = Term.const () in guard fn)

let pos_int =
  let parser s =
    match int_of_string_opt s with
    | Some n when n >= 1 -> Ok n
    | _ -> Error (Printf.sprintf "expected integer >= 1, got %S" s)
  in
  Arg.Conv.make ~docv:"INT" ~parser ~pp:Format.pp_print_int ()

let host_conv ~repo =
  Arg.Conv.make ~docv:"HOST" ~parser:(Env.parse_host ~repo) ~pp:Format.pp_print_string ()

let input_conv =
  Arg.Conv.make ~docv:"INPUT" ~parser:Env.parse_input ~pp:Format.pp_print_string ()

let sync_cmd =
  let info = Cmd.info "sync" ~doc:"Rebuild and activate this host" in
  let dry = Arg.(value & flag & info ["n"; "dry"] ~doc:"Only print actions.") in
  let ask = Arg.(value & flag & info ["a"; "ask"] ~doc:"Ask for confirmation.") in
  let verbose = Arg.(value & flag & info ["v"; "verbose"] ~doc:"Increase verbosity.") in
  let no_nom = Arg.(value & flag & info ["no-nom"] ~doc:"Do not use nix-output-monitor.") in
  Cmd.make info (
    let+ dry and+ ask and+ verbose and+ no_nom in
    guard (fun () -> Sync.sync ~dry ~ask ~verbose ~no_nom ())
  )

let rollback_cmd =
  let info = Cmd.info "rollback" ~doc:"Roll back to a previous system generation" in
  let gen = Arg.(value & pos 0 (some pos_int) None & info [] ~docv:"GEN" ~doc:"Target generation number.") in
  Cmd.make info (
    let+ gen in
    guard (fun () -> Sync.rollback ?gen ())
  )

let gc_cmd =
  let info = Cmd.info "gc" ~doc:"Clean profiles and optimise the store" in
  let user = Arg.(value & flag & info ["u"; "user"] ~doc:"Only this user's profiles.") in
  let keep = Arg.(value & opt pos_int 3 & info ["k"; "keep"] ~docv:"INT" ~doc:"Minimum number of generations to keep.") in
  let keep_since =
    Arg.(value & opt (some string) None & info ["K"; "keep-since"] ~docv:"DURATION"
           ~doc:"Keep generations and gcroots newer than $(docv) (e.g. 14d).")
  in
  let dry = Arg.(value & flag & info ["n"; "dry"] ~doc:"Only print actions.") in
  let ask = Arg.(value & flag & info ["a"; "ask"] ~doc:"Ask for confirmation.") in
  Cmd.make info (
    let+ user and+ keep and+ keep_since and+ dry and+ ask in
    guard (fun () -> Gc.gc ~user ~keep ~keep_since ~dry ~ask)
  )

let pull ~repo = function
  | `All -> Sh.run ["nix"; "flake"; "update"; "--flake"; repo]
  | `Inputs ins -> Sh.run (["nix"; "flake"; "update"; "--flake"; repo] @ ins)

let pull_cmd ~repo =
  let info = Cmd.info "pull" ~doc:"Update flake inputs" in
  let all = Arg.(value & flag & info ["a"; "all"] ~doc:"Update all flake inputs.") in
  let inputs = Arg.(value & pos_all input_conv [] & info [] ~docv:"INPUT" ~doc:"Flake input(s) to update.") in
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
    guard (fun () -> pull ~repo target)
  )

let gens () =
  match Env.os with
  | Env.Darwin -> Sh.run ["sudo"; "darwin-rebuild"; "--list-generations"]
  | Env.Linux -> Sh.run ["nh"; "os"; "info"]

(* nh loads this host's system config (config/options/pkgs) from NH_FLAKE,
   which Env.init_repo exports; -H keeps it in step with SS_HOST. *)
let repl () =
  match Env.os with
  | Env.Darwin -> Sh.run ["nh"; "darwin"; "repl"; "-H"; Env.host]
  | Env.Linux -> Sh.run ["nh"; "os"; "repl"; "-H"; Env.host]

let path_cmd ~repo =
  let info = Cmd.info "path" ~doc:"Print a path inside the repo" in
  let area_doc = Printf.sprintf "Repo area (%s)." (Arg.doc_alts_enum Path.areas) in
  let area = Arg.(value & pos 0 (enum Path.areas) Path.Repo & info [] ~docv:"AREA" ~doc:area_doc) in
  let rest = Arg.(value & pos_right 0 string [] & info [] ~docv:"SUBPATH" ~doc:"Optional subpath segment(s).") in
  Cmd.make info (
    let+ area and+ rest in
    guard (fun () -> print_endline (Path.resolve ~repo ~area rest))
  )

let deploy_cmd ~repo =
  let info = Cmd.info "deploy" ~doc:"Rebuild and activate configuration on remote host(s)" in
  let hosts = Arg.(non_empty & pos_all (host_conv ~repo) [] & info [] ~docv:"HOST" ~doc:"Target host(s).") in
  Cmd.make info (
    let+ hosts in
    guard (fun () -> Deploy.deploy hosts)
  )

let enroll_cmd ~repo =
  let info = Cmd.info "enroll" ~doc:"Provision the sops age machine key on a host" in
  let host = Arg.(required & pos 0 (some (host_conv ~repo)) None & info [] ~docv:"HOST" ~doc:"Target host.") in
  Cmd.make info (
    let+ host in
    guard (fun () -> Enroll.enroll ~repo host)
  )

let root_cmd ~repo =
  let info = Cmd.info "ss" ~doc:"Dotfiles management helper" in
  let default = let+ () = Term.const () in guard Sync.sync in
  Cmd.group info ~default [
    sync_cmd;
    rollback_cmd;
    unit_cmd "swap" ~doc:"Swap store links for mutable copies" (Impure.swap ~repo);
    unit_cmd "unswap" ~doc:"Restore store links (re-runs the hjem agent)" Impure.unswap;
    unit_cmd "gens" ~doc:"List system generations" gens;
    gc_cmd;
    pull_cmd ~repo;
    unit_cmd "repl" ~doc:"Open a nix repl with this host's configuration loaded" repl;
    path_cmd ~repo;
    deploy_cmd ~repo;
    enroll_cmd ~repo;
  ]

let () =
  (* Ctrl-C raises Break so finalisers, temp cleanup and child reaping run. *)
  Sys.catch_break true;
  let repo = Env.init_repo () in
  exit (Cmd.eval_result (root_cmd ~repo))
