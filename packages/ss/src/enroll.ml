let patch_sops ~host ~public sops =
  if String.includes ~affix:("\n  - &" ^ host ^ " ") sops then
    Env.fail "%s is already enrolled in .sops.yaml" host;
  match String.split_first ~sep:"\ncreation_rules:" sops with
  | None -> Env.fail "missing creation_rules: in .sops.yaml"
  | Some (before, after) ->
      Printf.sprintf "%s\n  - &%-8s %s\ncreation_rules:%s" before host public after

let enroll ~repo host =
  (match Env.parse_host ~repo host with Ok _ -> () | Error e -> Env.fail "%s" e);
  let sops_file = Filename.concat repo ".sops.yaml" in
  let original = In_channel.with_open_bin sops_file In_channel.input_all in
  let secret = Sh.read ~stderr:`Null ["age-keygen"] in
  let public = Sh.read ~stdin:(`String secret) ["age-keygen"; "-y"] |> String.trim in
  let updated = patch_sops ~host ~public original in
  (* Install the key exactly once, never overwriting: the secret goes straight
     into a 0600 temp file inside the 0700 key dir and is hard-linked into
     place. ln fails if key.txt exists, and key.txt only ever appears
     complete; the data is written once, ln and rm only rename it. *)
  let target = "root@" ^ host in
  let ssh args = "ssh" :: "-n" :: target :: args in
  let key_dir = "/var/lib/sops-nix" in
  let key_file = key_dir ^ "/key.txt" in
  let probe = ssh ["test"; "-e"; key_file] in
  (match Sh.run_status probe with
   | Unix.WEXITED 0 -> Env.fail "%s already has %s" host key_file
   | Unix.WEXITED 1 -> ()
   | st -> Sh.check probe st);
  Sh.run (ssh ["install"; "-d"; "-m"; "700"; key_dir]);
  let tmp = String.trim (Sh.read (ssh ["mktemp"; key_dir ^ "/.key.XXXXXX"])) in
  Fun.protect
    ~finally:(fun () -> ignore (Sh.ok (ssh ["rm"; "-f"; tmp])))
    (fun () ->
      Sh.run ~stdin:(`String secret) ~stdout:`Null ["ssh"; target; "tee"; tmp];
      Sh.run (ssh ["ln"; tmp; key_file]));
  Os.write_file sops_file updated;
  Sh.run ["git"; "-C"; repo; "--no-pager"; "diff"; "--"; ".sops.yaml"];
  Printf.printf "%s: enrolled (%s)\n" host public
