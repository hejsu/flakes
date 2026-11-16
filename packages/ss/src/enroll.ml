let patch_sops ~host ~public sops =
  if String.includes ~affix:("\n  - &" ^ host ^ " ") sops then
    failwith (host ^ " is already enrolled in .sops.yaml");
  match String.split_first ~sep:"\ncreation_rules:" sops with
  | None -> failwith "missing creation_rules: in .sops.yaml"
  | Some (before, after) ->
      Printf.sprintf "%s\n  - &%-8s %s\ncreation_rules:%s" before host public after

let enroll ~repo host =
  Env.require_host ~repo host;
  let sops_file = Filename.concat repo ".sops.yaml" in
  let original = In_channel.with_open_bin sops_file In_channel.input_all in
  let secret = Sh.read ~stderr:`Null ["age-keygen"] in
  let public = Sh.read ~stdin:(`String secret) ["age-keygen"; "-y"] |> String.trim in
  let updated = patch_sops ~host ~public original in
  let target = "root@" ^ host in
  if not (Sh.ok ["ssh"; "-n"; target; "test"; "!"; "-e"; "/var/lib/sops-nix/key.txt"]) then
    failwith (host ^ " already has /var/lib/sops-nix/key.txt");
  let remote_tmp = Sh.read ["ssh"; "-n"; target; "mktemp"] |> String.trim in
  Fun.protect
    ~finally:(fun () -> ignore (Sh.ok ["ssh"; "-n"; target; "rm"; "-f"; remote_tmp]))
    (fun () ->
      Sh.run ~stdin:(`String secret) ["ssh"; target; "cat > " ^ remote_tmp];
      Sh.run ["ssh"; "-n"; target; "install"; "-d"; "-m"; "700"; "/var/lib/sops-nix"];
      Sh.run ["ssh"; "-n"; target; "install"; "-m"; "600"; remote_tmp; "/var/lib/sops-nix/key.txt"]);
  Out_channel.with_open_bin sops_file (fun oc -> Out_channel.output_string oc updated);
  Sh.run ["git"; "-C"; repo; "--no-pager"; "diff"; "--"; ".sops.yaml"];
  Printf.printf "%s: enrolled (%s)\n" host public
