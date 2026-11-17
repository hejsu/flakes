let sync ?(dry = false) ?(ask = false) ?(verbose = false) ?(no_nom = false) () =
  Impure.require_clean ();
  let flags =
    (if dry then ["--dry"] else [])
    @ (if ask then ["--ask"] else [])
    @ (if verbose then ["--verbose"] else [])
    @ (if no_nom then ["--no-nom"] else [])
  in
  match Env.os with
  | Linux -> Sh.run (["nh"; "os"; "switch"] @ flags)
  | Darwin ->
      (* WORKAROUND: https://github.com/nix-community/nh/issues/739 *)
      Os.with_tmp_dir ~prefix:"nh-switch-" (fun scratch ->
          Sh.run ~cwd:scratch (["nh"; "darwin"; "switch"] @ flags))

let rollback ?gen () =
  Impure.require_clean ();
  match Env.os, gen with
  | Linux, None -> Sh.run ["nh"; "os"; "rollback"]
  | Linux, Some g -> Sh.run ["nh"; "os"; "rollback"; "--to"; string_of_int g]
  | Darwin, None -> Sh.run ["sudo"; "darwin-rebuild"; "--rollback"]
  | Darwin, Some g -> Sh.run ["sudo"; "darwin-rebuild"; "--switch-generation"; string_of_int g]
