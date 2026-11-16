let var name =
  match Sys.getenv_opt name with
  | Some v when v <> "" -> Some v
  | _ -> None

let init_repo () =
  let repo =
    match var "NH_FLAKE" with
    | Some p -> p
    | None -> Filename.concat (Sys.getenv "HOME") ".config/dotfiles"
  in
  Unix.putenv "NH_FLAKE" repo;
  repo

let is_darwin () =
  (Sh.read ["uname"; "-s"] |> String.trim) = "Darwin"

let current_host () =
  match var "SS_HOST" with
  | Some h -> h
  | None -> Sh.read ["hostname"; "-s"] |> String.trim

let is_seg s =
  s <> "" && s <> "." && s <> ".." && not (String.contains s '/')

let require_host ~repo name =
  let ok =
    is_seg name
    && (match var "SS_HOSTS" with
        | Some hs when List.mem name (String.split_on_char ' ' hs) -> true
        | _ -> Sys.file_exists (Printf.sprintf "%s/hosts/%s/default.nix" repo name))
  in
  if not ok then failwith (Printf.sprintf "no such host '%s'" name)

let require_input name =
  let ok =
    is_seg name
    && (match var "SS_INPUTS" with
        | Some ins -> List.mem name (String.split_on_char ' ' ins)
        | None -> true)
  in
  if not ok then failwith (Printf.sprintf "no such input '%s'" name)
