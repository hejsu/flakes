(* Only what plain commands can't do: guarantee a temp dir is removed on every
   exit path, and atomically write an OCaml string. Everything else (mkdir,
   rm, cp, chmod) goes through [Sh.run]; per-command cwd is [Sh.run ~cwd]. *)

(* Python's TemporaryDirectory: random name, 0700, removed on return,
   exception and Ctrl-C (Break). *)
let with_tmp_dir ?(prefix = "ss-") fn =
  let dir = Filename.temp_dir prefix "" in
  Fun.protect
    ~finally:(fun () -> ignore (Sh.ok ["rm"; "-rf"; dir]))
    (fun () -> fn dir)

(* Write a sibling temp file, fsync, rename over [path]: readers see the old
   or the new content, never a partial one. A symlink at [path] is replaced,
   not written through. Keeps a regular file's mode unless [mode] is given. *)
let write_file ?mode path contents =
  let perm =
    match mode with
    | Some m -> m
    | None ->
        match Unix.lstat path with
        | { st_kind = S_REG; st_perm; _ } -> st_perm
        | _ | (exception Unix.Unix_error (ENOENT, _, _)) -> 0o644
  in
  let tmp, oc =
    Filename.open_temp_file ~temp_dir:(Filename.dirname path) ~mode:[Open_binary]
      (".ss-" ^ Filename.basename path ^ "-") ".tmp"
  in
  try
    Fun.protect ~finally:(fun () -> close_out_noerr oc) (fun () ->
        output_string oc contents;
        flush oc;
        let fd = Unix.descr_of_out_channel oc in
        Unix.fchmod fd perm;
        Unix.fsync fd);
    Unix.rename tmp path
  with exn ->
    let bt = Printexc.get_raw_backtrace () in
    (try Sys.remove tmp with Sys_error _ -> ());
    Printexc.raise_with_backtrace exn bt
