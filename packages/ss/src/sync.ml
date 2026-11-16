let sync ?(dry = false) ?(ask = false) ?(verbose = false) ?(no_nom = false) () =
  Impure.require_clean ();
  let flags =
    (if dry then ["--dry"] else [])
    @ (if ask then ["--ask"] else [])
    @ (if verbose then ["--verbose"] else [])
    @ (if no_nom then ["--no-nom"] else [])
  in
  if not (Env.is_darwin ()) then
    Sh.run (["nh"; "os"; "switch"] @ flags)
  else
    (* WORKAROUND: https://github.com/nix-community/nh/issues/739 *)
    let scratch = Filename.temp_dir "nh-switch-" "" in
    let old_cwd = Sys.getcwd () in
    Fun.protect
      ~finally:(fun () ->
        (try Unix.chdir old_cwd with _ -> ());
        ignore (Sh.ok ["rm"; "-rf"; scratch]))
      (fun () ->
        Unix.chdir scratch;
        Sh.run (["nh"; "darwin"; "switch"] @ flags))

let rollback ?gen () =
  Impure.require_clean ();
  match Env.is_darwin (), gen with
  | false, None -> Sh.run ["nh"; "os"; "rollback"]
  | false, Some g -> Sh.run ["nh"; "os"; "rollback"; "--to"; string_of_int g]
  | true, None -> Sh.run ["sudo"; "darwin-rebuild"; "--rollback"]
  | true, Some g -> Sh.run ["sudo"; "darwin-rebuild"; "--switch-generation"; string_of_int g]
