exception Error of string

let fail fmt = Printf.ksprintf (fun s -> raise (Error s)) fmt

type os = Darwin | Linux

let var name =
  match Sys.getenv_opt name with
  | Some v when v <> "" -> Some v
  | _ -> None

let os = if Host_os.system = "macosx" then Darwin else Linux
let home = Sys.getenv "HOME"
let uid = Unix.getuid ()

let user =
  try (Unix.getpwuid uid).pw_name
  with Not_found -> Option.value (var "USER") ~default:"unknown"

let host =
  match var "SS_HOST" with
  | Some h -> h
  | None ->
      let h = Unix.gethostname () in
      match String.split_first ~sep:"." h with
      | Some (s, _) -> s
      | None -> h

let init_repo () =
  let repo = Option.value (var "NH_FLAKE") ~default:(Filename.concat home ".config/dotfiles") in
  Unix.putenv "NH_FLAKE" repo;
  repo

let is_seg s =
  s <> "" && s <> "." && s <> ".." && not (String.contains s '/')

let parse_host ~repo name =
  let ok =
    is_seg name
    && (match var "SS_HOSTS" with
        | Some hs -> List.mem name (String.split_on_char ' ' hs)
        | None -> Sys.file_exists (Printf.sprintf "%s/hosts/%s/default.nix" repo name))
  in
  if ok then Ok name else Error (Printf.sprintf "no such NixOS target host %S" name)

let parse_input name =
  let ok =
    is_seg name
    && (match var "SS_INPUTS" with
        | Some ins -> List.mem name (String.split_on_char ' ' ins)
        | None -> true)
  in
  if ok then Ok name else Error (Printf.sprintf "no such input %S" name)
