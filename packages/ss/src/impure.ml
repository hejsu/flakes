let require_clean ?host () =
  let state =
    match host with
    | None ->
        let f = Filename.concat (Sys.getenv "HOME") ".local/state/HJEM_IMPURE_ACTIVE" in
        if Sys.file_exists f then String.trim (In_channel.with_open_bin f In_channel.input_all) else ""
    | Some h ->
        Sh.read ~stderr:`Null
          ["ssh"; "-n"; h; "cat \"$HOME/.local/state/HJEM_IMPURE_ACTIVE\" 2>/dev/null || true"]
        |> String.trim
  in
  if state = "1" then
    let where, hint =
      match host with
      | None -> "", "ss unswap"
      | Some h -> " on " ^ h, "ss unswap " ^ h
    in
    failwith (Printf.sprintf
      "impure mode is active%s\n  \
       activation would replace your mutable copies with store links.\n  \
       run '%s' first, or copy out the edits you want to keep."
      where hint)

let swap () =
  Sh.run ["hjem-impure"]

let unswap () =
  print_endline "Re-linking hjem files to the store (local swapped copies will be replaced)...";
  if Env.is_darwin () then
    let uid = Sh.read ["id"; "-u"] |> String.trim in
    Sh.run ["launchctl"; "kickstart"; "-k"; "gui/" ^ uid ^ "/org.hjem.activate"]
  else
    let user = Sh.read ["id"; "-un"] |> String.trim in
    Sh.run ["sudo"; "systemctl"; "start"; "hjem-activate@" ^ user ^ ".service"]
