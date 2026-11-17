(* Process execution.

   Spawning goes through Jane Street's [spawn] (what dune uses): the child
   chdirs itself for [?cwd] and resets every signal to SIG_DFL before exec.
   That lets us ignore SIGPIPE process-wide, as Python and Rust do, without
   children inheriting it.

   I/O follows Python's [subprocess.Popen.communicate]: one select loop feeds
   stdin and drains stdout concurrently, stdin is closed once written, EPIPE
   just stops feeding, and the exit status is the verdict. *)

(* EPIPE instead of death when a child stops reading early. ss itself writing
   to a closed stdout then raises [Sys_error], reported by [Main.guard]. *)
let () = Sys.set_signal Sys.sigpipe Sys.Signal_ignore

type in_spec = [ `Inherit | `Null | `String of string ]
type out_spec = [ `Inherit | `Null ]

let rec eintr f x =
  try f x with Unix.Unix_error (Unix.EINTR, _, _) -> eintr f x

let close_noerr fd = try Unix.close fd with Unix.Unix_error _ -> ()

(* Fds opened for one run; every exit path closes whatever is still owned. *)
module Fds = struct
  type t = Unix.file_descr list ref

  let create () : t = ref []
  let add t fd = t := fd :: !t; fd

  let close t fd =
    if List.mem fd !t then (t := List.filter (( <> ) fd) !t; close_noerr fd)

  let close_all t = List.iter close_noerr !t; t := []

  let pipe t =
    let r, w = Spawn.safe_pipe () in
    add t r, add t w
end

(* Current environment with [env] overriding same-named entries. *)
let environment env =
  let overridden kv =
    match String.index_opt kv '=' with
    | Some i -> List.mem_assoc (String.sub kv 0 i) env
    | None -> false
  in
  let inherited = List.filter (fun kv -> not (overridden kv)) (Array.to_list (Unix.environment ())) in
  inherited @ List.map (fun (k, v) -> k ^ "=" ^ v) env

(* [spawn] does no PATH lookup. Like execvp/Python: names containing '/' are
   used as is, otherwise the first executable regular file on PATH (taken
   from [env] when overridden) wins. *)
let resolve ~env prog =
  if String.contains prog '/' then prog
  else
    let path =
      match List.assoc_opt "PATH" env with
      | Some p -> p
      | None -> Option.value (Sys.getenv_opt "PATH") ~default:"/usr/bin:/bin"
    in
    let executable file =
      match Unix.stat file with
      | { st_kind = S_REG; _ } -> (try Unix.access file [X_OK]; true with Unix.Unix_error _ -> false)
      | _ | (exception Unix.Unix_error _) -> false
    in
    let candidates =
      String.split_on_char ':' path
      |> List.map (fun dir -> Filename.concat (if dir = "" then "." else dir) prog)
    in
    match List.find_opt executable candidates with
    | Some file when Filename.is_relative file -> Filename.concat (Sys.getcwd ()) file
    | Some file -> file
    | None -> Env.fail "%s: command not found" prog

let signal_name s =
  [ Sys.sighup, "SIGHUP"; Sys.sigint, "SIGINT"; Sys.sigquit, "SIGQUIT";
    Sys.sigabrt, "SIGABRT"; Sys.sigkill, "SIGKILL"; Sys.sigsegv, "SIGSEGV";
    Sys.sigpipe, "SIGPIPE"; Sys.sigterm, "SIGTERM" ]
  |> List.assoc_opt s
  |> Option.value ~default:(Printf.sprintf "signal %d" s)

let check args = function
  | Unix.WEXITED 0 -> ()
  | Unix.WEXITED n -> Env.fail "command %S exited with %d" (String.concat " " args) n
  | Unix.WSIGNALED s | Unix.WSTOPPED s ->
      Env.fail "command %S killed by %s" (String.concat " " args) (signal_name s)

let chunk = 65536

(* [input]: our write end and the bytes to feed; [output]: our read end. *)
let communicate fds ~input ~output =
  let buf = Buffer.create 4096 in
  let bytes = Bytes.create chunk in
  let input = ref input and output = ref output in
  let stop_input () =
    Option.iter (fun (fd, _, _) -> Fds.close fds fd) !input;
    input := None
  in
  (match !input with Some (_, s, _) when s = "" -> stop_input () | _ -> ());
  let feed fd s off =
    match Unix.single_write_substring fd s off (min chunk (String.length s - off)) with
    | n when off + n = String.length s -> stop_input ()
    | n -> input := Some (fd, s, off + n)
    | exception Unix.Unix_error ((EAGAIN | EWOULDBLOCK | EINTR), _, _) -> ()
    | exception Unix.Unix_error (EPIPE, _, _) -> stop_input ()
  in
  let drain fd =
    match Unix.read fd bytes 0 chunk with
    | 0 -> Fds.close fds fd; output := None
    | n -> Buffer.add_subbytes buf bytes 0 n
    | exception Unix.Unix_error ((EAGAIN | EWOULDBLOCK | EINTR), _, _) -> ()
  in
  let rec loop () =
    let wset = match !input with Some (fd, _, _) -> [fd] | None -> [] in
    let rset = Option.to_list !output in
    if wset <> [] || rset <> [] then (
      let rable, wable, _ =
        try Unix.select rset wset [] (-1.)
        with Unix.Unix_error (EINTR, _, _) -> [], [], []
      in
      (match !input with
       | Some (fd, s, off) when wable <> [] -> feed fd s off
       | _ -> ());
      (match !output with
       | Some fd when rable <> [] -> drain fd
       | _ -> ());
      loop ())
  in
  loop ();
  Buffer.contents buf

(* Never leave a child behind. On Ctrl-C the child got SIGINT too, so let it
   exit; on any other failure kill it. A second Ctrl-C while waiting kills. *)
let rec reap pid =
  try ignore (eintr (Unix.waitpid []) pid) with
  | Sys.Break -> (try Unix.kill pid Sys.sigkill with Unix.Unix_error _ -> ()); reap pid
  | Unix.Unix_error (ECHILD, _, _) -> ()

let abort pid exn =
  (match exn with
   | Sys.Break -> ()
   | _ -> (try Unix.kill pid Sys.sigkill with Unix.Unix_error _ -> ()));
  reap pid

let spawn ~cwd ~env ~prog ~argv ~stdin ~stdout ~stderr =
  let env = if env = [] then None else Some (Spawn.Env.of_list (environment env)) in
  let cwd = Option.map (fun dir -> Spawn.Working_dir.Path dir) cwd in
  try Spawn.spawn ?env ?cwd ~prog ~argv ~stdin ~stdout ~stderr ()
  with Unix.Unix_error (e, fn, arg) ->
    match fn with
    | "chdir" -> Env.fail "%s: cannot enter %s: %s" (List.hd argv) arg (Unix.error_message e)
    | _ -> Env.fail "%s: %s" (List.hd argv) (Unix.error_message e)

let spawn_and_wait ?cwd ?(env = []) ~(stdin : in_spec) ~(stdout : out_spec) ~(stderr : out_spec) ~capture args =
  let name = match args with [] -> invalid_arg "Sh: empty command" | p :: _ -> p in
  let prog = resolve ~env name in
  let fds = Fds.create () in
  Fun.protect ~finally:(fun () -> Fds.close_all fds) (fun () ->
      let null () = Fds.add fds (Unix.openfile "/dev/null" [O_RDWR; O_CLOEXEC] 0) in
      let sink default = function `Inherit -> default | `Null -> null () in
      let in_fd, input =
        match stdin with
        | `Inherit -> Unix.stdin, None
        | `Null -> null (), None
        | `String s ->
            let r, w = Fds.pipe fds in
            Unix.set_nonblock w;
            r, Some (w, s, 0)
      in
      let out_fd, output =
        if capture then (let r, w = Fds.pipe fds in w, Some r)
        else sink Unix.stdout stdout, None
      in
      let err_fd = sink Unix.stderr stderr in
      let pid = spawn ~cwd ~env ~prog ~argv:args ~stdin:in_fd ~stdout:out_fd ~stderr:err_fd in
      List.iter (Fds.close fds) [in_fd; out_fd; err_fd];
      match
        let out = if input = None && output = None then "" else communicate fds ~input ~output in
        out, snd (eintr (Unix.waitpid []) pid)
      with
      | result -> result
      | exception exn ->
          let bt = Printexc.get_raw_backtrace () in
          abort pid exn;
          Printexc.raise_with_backtrace exn bt)

let run_status ?cwd ?env ?(stdin = `Inherit) ?(stdout = `Inherit) ?(stderr = `Inherit) args =
  snd (spawn_and_wait ?cwd ?env ~stdin ~stdout ~stderr ~capture:false args)

let run ?cwd ?env ?stdin ?stdout ?stderr args =
  check args (run_status ?cwd ?env ?stdin ?stdout ?stderr args)

let ok ?cwd ?env ?stdin ?stdout ?stderr args =
  run_status ?cwd ?env ?stdin ?stdout ?stderr args = Unix.WEXITED 0

let read ?cwd ?env ?(stdin = `Inherit) ?(stderr = `Inherit) args =
  let out, status = spawn_and_wait ?cwd ?env ~stdin ~stdout:`Inherit ~stderr ~capture:true args in
  check args status;
  out
