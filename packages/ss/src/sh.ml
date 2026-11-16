type in_spec = [ `Inherit | `Null | `String of string ]
type out_spec = [ `Inherit | `Null ]

let rec waitpid pid =
  try snd (Unix.waitpid [] pid)
  with Unix.Unix_error (Unix.EINTR, _, _) -> waitpid pid

let dev_null () = Unix.openfile "/dev/null" [O_RDWR; O_CLOEXEC] 0

let fd_of_string s =
  let path, oc = Filename.open_temp_file ~mode:[Open_binary] "ss-in-" "" in
  Fun.protect ~finally:(fun () -> try Unix.unlink path with _ -> ()) @@ fun () ->
  Fun.protect ~finally:(fun () -> close_out_noerr oc) @@ fun () ->
  output_string oc s;
  flush oc;
  Unix.openfile path [O_RDONLY; O_CLOEXEC] 0

let with_in (spec : in_spec) fn =
  match spec with
  | `Inherit -> fn Unix.stdin
  | `Null -> let fd = dev_null () in Fun.protect ~finally:(fun () -> Unix.close fd) (fun () -> fn fd)
  | `String s -> let fd = fd_of_string s in Fun.protect ~finally:(fun () -> Unix.close fd) (fun () -> fn fd)

let with_out default (spec : out_spec) fn =
  match spec with
  | `Inherit -> fn default
  | `Null -> let fd = dev_null () in Fun.protect ~finally:(fun () -> Unix.close fd) (fun () -> fn fd)

let spawn ~stdin ~stderr prog args out_fd =
  with_in stdin @@ fun in_fd ->
  with_out Unix.stderr stderr @@ fun err_fd ->
  try Unix.create_process prog (Array.of_list args) in_fd out_fd err_fd
  with Unix.Unix_error (e, _, _) ->
    failwith (Printf.sprintf "%s: %s" prog (Unix.error_message e))

let check args = function
  | Unix.WEXITED 0 -> ()
  | Unix.WEXITED n -> failwith (Printf.sprintf "command %S exited with %d" (String.concat " " args) n)
  | Unix.WSIGNALED s | Unix.WSTOPPED s ->
      failwith (Printf.sprintf "command %S terminated by signal %d" (String.concat " " args) s)

let run_status ?(stdin = `Inherit) ?(stdout = `Inherit) ?(stderr = `Inherit) = function
  | [] -> invalid_arg "Sh: empty command"
  | prog :: _ as args ->
      with_out Unix.stdout stdout (fun out_fd -> waitpid (spawn ~stdin ~stderr prog args out_fd))

let run ?stdin ?stdout ?stderr args =
  check args (run_status ?stdin ?stdout ?stderr args)

let ok ?stdin ?stdout ?stderr args =
  run_status ?stdin ?stdout ?stderr args = Unix.WEXITED 0

let read ?(stdin = `Inherit) ?(stderr = `Inherit) = function
  | [] -> invalid_arg "Sh.read: empty command"
  | prog :: _ as args ->
      let r_fd, w_fd = Unix.pipe ~cloexec:true () in
      let ic = Unix.in_channel_of_descr r_fd in
      set_binary_mode_in ic true;
      let s, st =
        Fun.protect ~finally:(fun () -> close_in_noerr ic) @@ fun () ->
        let pid =
          Fun.protect ~finally:(fun () -> Unix.close w_fd)
            (fun () -> spawn ~stdin ~stderr prog args w_fd)
        in
        let s = In_channel.input_all ic in
        s, waitpid pid
      in
      check args st;
      s
