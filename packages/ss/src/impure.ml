open Yojson.Basic.Util

type state = { active : bool; source_dir : string }
type action = Link of string | Copy of string

let rel_state = ".local/state/impure.json"
let state_file = Filename.concat Env.home rel_state

let manifest_file =
  match Env.os with
  | Darwin -> Filename.concat Env.home "Library/Application Support/Hjem/manifest.json"
  | Linux -> "/var/lib/hjem/manifest-" ^ Env.user ^ ".json"

let state_of_json j =
  { active = j |> member "active" |> to_bool;
    source_dir = j |> member "sourceDir" |> to_string }

let json_of_string ~source s =
  try Yojson.Basic.from_string s
  with Yojson.Json_error msg -> Env.fail "parse %s: %s" source msg

let state_of_string ~source s =
  try state_of_json (json_of_string ~source s)
  with Type_error (msg, _) -> Env.fail "parse %s: %s" source msg

let read_state () = state_of_string ~source:state_file (In_channel.with_open_bin state_file In_channel.input_all)

let write_state s =
  Os.write_file state_file
    (Yojson.Basic.to_string (`Assoc ["active", `Bool s.active; "sourceDir", `String s.source_dir]))

let require_enabled () =
  if not (Sys.file_exists state_file) then
    Env.fail "impure mode is disabled on this host";
  read_state ()

let require_clean () =
  if Sys.file_exists state_file && (read_state ()).active then
    Env.fail "impure mode is active; activation would replace mutable copies with store links (run 'ss unswap' first)"

let parse_entry ~repo ~prefix e =
  let dst = e |> member "target" |> to_string in
  match e |> member "type" |> to_string with
  | "symlink" when dst <> state_file ->
      let src = e |> member "source" |> to_string in
      let act =
        match String.split_first ~sep:prefix src with
        | Some ("", rel) -> Link (Filename.concat repo rel)
        | _ -> Copy src
      in
      Some (dst, act)
  | _ -> None

let apply_entry (dst, act) =
  match (Unix.lstat dst).st_kind with
  | S_LNK ->
      Unix.unlink dst;
      begin match act with
      | Link target ->
          Unix.symlink target dst;
          Printf.printf "%s -> %s\n%!" dst target
      | Copy src ->
          Sh.run ["cp"; "-RL"; src; dst];
          Sh.run ["chmod"; "-R"; "u+w"; dst];
          Printf.printf "%s (copied)\n%!" dst
      end
  | _ | exception Unix.Unix_error _ ->
      Printf.eprintf "skipping non-symlink: %s\n%!" dst

let swap ~repo () =
  let s = require_enabled () in
  if s.active then print_endline "Already in impure mode."
  else (
    let prefix = s.source_dir ^ "/" in
    let entries =
      try
        json_of_string ~source:manifest_file (In_channel.with_open_bin manifest_file In_channel.input_all)
        |> member "files" |> to_list
        |> List.filter_map (parse_entry ~repo ~prefix)
      with Type_error (msg, _) -> Env.fail "parse %s: %s" manifest_file msg
    in
    (* Mark active first: a partial swap must still block activation. *)
    write_state { s with active = true };
    List.iter apply_entry entries)

let unswap () =
  ignore (require_enabled ());
  print_endline "Re-linking hjem files to the store (local swapped copies will be replaced)...";
  match Env.os with
  | Darwin ->
      let target = Printf.sprintf "gui/%d/org.hjem.activate" Env.uid in
      Sh.run ["launchctl"; "kickstart"; "-k"; target]
  | Linux ->
      Sh.run ["sudo"; "systemctl"; "start"; "hjem-activate@" ^ Env.user ^ ".service"]
