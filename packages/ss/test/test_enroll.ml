open Ss_lib

let ( // ) = Filename.concat
let read_file p = In_channel.with_open_bin p In_channel.input_all

let write_file ?mode path content =
  let perm = Option.value mode ~default:0o644 in
  Out_channel.with_open_gen [Open_wronly; Open_creat; Open_trunc; Open_binary] perm path
    (fun oc -> Out_channel.output_string oc content);
  Option.iter (Unix.chmod path) mode

let se_key = "age1se1qdcylfv526lvt0rtz9sylj5nsc7gwvjgla6ruwv7gqp64h2p8h4z2utwew9"
let key_a  = "age1esdgkcyafrjejyzrsdqnkl54eqrvxn2y857rrdr0y6p697cxe42qcytlhu"
let key_b  = "age15qxamscjw2j42dckh30wtawdx38tdektgdtnlhqtme2q32qe5v8q7nk0cx"

let base_sops =
  Printf.sprintf
    "keys:\n\
    \  - &se       %s\n\
    \  - &rhayader %s\n\
     creation_rules:\n\
    \  - path_regex: hosts/rhayader/assets/.*\n\
    \    key_groups:\n\
    \    - age:\n\
    \      - *rhayader\n\
    \      - *se\n"
    se_key key_b

let fails fn =
  try ignore (fn ()); false
  with Env.Error _ -> true

let test_patch_append () =
  let updated = Enroll.patch_sops ~host:"syd" ~public:key_a base_sops in
  let expected =
    Printf.sprintf
      "keys:\n\
      \  - &se       %s\n\
      \  - &rhayader %s\n\
      \  - &syd      %s\n\
       creation_rules:\n\
      \  - path_regex: hosts/rhayader/assets/.*\n\
      \    key_groups:\n\
      \    - age:\n\
      \      - *rhayader\n\
      \      - *se\n"
      se_key key_b key_a
  in
  Alcotest.(check string) "appends aligned anchor at bottom of keys:" expected updated;
  Alcotest.(check bool) "rejects duplicate enroll"
    true (fails (fun () -> Enroll.patch_sops ~host:"syd" ~public:key_a updated))

let test_patch_prefix_and_comments () =
  let with_prefix = Enroll.patch_sops ~host:"rha" ~public:key_a base_sops in
  Alcotest.(check bool) "prefix host name does not collide with &rhayader"
    true (List.mem ("  - &rha      " ^ key_a) (String.split_on_char '\n' with_prefix));
  let commented =
    Printf.sprintf
      "# age keys:\n\
       keys: # anchors\n\
      \  # - &old %s\n\
      \  - &se       %s\n\
       creation_rules: # rules\n"
      key_b se_key
  in
  let expected =
    Printf.sprintf
      "# age keys:\n\
       keys: # anchors\n\
      \  # - &old %s\n\
      \  - &se       %s\n\
      \  - &old      %s\n\
       creation_rules: # rules\n"
      key_b se_key key_a
  in
  Alcotest.(check string) "ignores # age keys: and # - &old comments"
    expected (Enroll.patch_sops ~host:"old" ~public:key_a commented);
  Alcotest.(check bool) "rejects missing creation_rules:"
    true (fails (fun () -> Enroll.patch_sops ~host:"syd" ~public:key_a "keys:\n  - &se age1xxx\n"))

let with_sandbox fn =
  Os.with_tmp_dir ~prefix:"ss-test-" (fun root ->
      let repo = root // "repo" in
      let bin = root // "bin" in
      let remote_root = root // "remote" in
      let remote_tmp = root // "remote-tmp" in
      Sh.run ["mkdir"; "-p"; repo // "hosts/syd"; bin; remote_root; remote_tmp];
      write_file (repo // "hosts/syd/default.nix") "{}\n";
      Sh.run ["git"; "-C"; repo; "init"; "-q"];
      write_file (repo // ".sops.yaml") base_sops;
      let ssh_stub =
        Printf.sprintf
          "#!/bin/sh\n\
           [ \"$1\" = \"-n\" ] && { exec </dev/null; shift; }\n\
           shift\n\
           [ -z \"$FAIL_UPLOAD\" ] || case \"$*\" in \"tee \"*) exit 1 ;; esac\n\
           cmd=$(printf '%%s' \"$*\" | sed \"s|/var/lib/sops-nix|%s/sops-nix|g\")\n\
           TMPDIR=%s exec sh -c \"$cmd\"\n"
          remote_root remote_tmp
      in
      write_file ~mode:0o755 (bin // "ssh") ssh_stub;
      let orig_path = Sys.getenv_opt "PATH" in
      let new_path = match orig_path with Some p when p <> "" -> bin ^ ":" ^ p | _ -> bin in
      Unix.putenv "PATH" new_path;
      Unix.putenv "FAIL_UPLOAD" "";
      Fun.protect
        ~finally:(fun () ->
          Unix.putenv "PATH" (Option.value orig_path ~default:"");
          Unix.putenv "FAIL_UPLOAD" "")
        (fun () ->
          fn ~repo ~key_file:(remote_root // "sops-nix/key.txt") ~remote_tmp))

let entries dir = Sys.readdir dir |> Array.to_list |> List.sort compare

let test_enroll_fresh () =
  with_sandbox (fun ~repo ~key_file ~remote_tmp ->
    Enroll.enroll ~repo "syd";
    Alcotest.(check int) "dir 0700"
      0o700 (Unix.stat (Filename.dirname key_file)).st_perm;
    Alcotest.(check int) "key 0600"
      0o600 (Unix.stat key_file).st_perm;
    Alcotest.(check (list string)) "key dir holds only key.txt"
      ["key.txt"] (entries (Filename.dirname key_file));
    Alcotest.(check int) "key is a single-name regular file"
      1 (Unix.lstat key_file).st_nlink;
    Alcotest.(check (list string)) "nothing staged in remote /tmp"
      [] (entries remote_tmp);
    let pub = Sh.read ["age-keygen"; "-y"; key_file] |> String.trim in
    let sops = read_file (repo // ".sops.yaml") in
    Alcotest.(check bool) "public key registered"
      true (List.mem ("  - &syd      " ^ pub) (String.split_on_char '\n' sops));
    let priv = read_file key_file in
    Alcotest.(check bool) "second enroll rejected"
      true (fails (fun () -> Enroll.enroll ~repo "syd"));
    Alcotest.(check string) "key untouched"
      priv (read_file key_file);
    Alcotest.(check string) "sops untouched"
      sops (read_file (repo // ".sops.yaml")))

let test_reject_existing_remote_key () =
  with_sandbox (fun ~repo ~key_file ~remote_tmp:_ ->
    Sh.run ["mkdir"; "-p"; "-m"; "700"; Filename.dirname key_file];
    write_file ~mode:0o600 key_file "existing-secret\n";
    Alcotest.(check bool) "refuses existing remote key"
      true (fails (fun () -> Enroll.enroll ~repo "syd"));
    Alcotest.(check string) "remote key preserved"
      "existing-secret\n" (read_file key_file);
    Alcotest.(check (list string)) "no temp file left beside it"
      ["key.txt"] (entries (Filename.dirname key_file));
    Alcotest.(check string) ".sops.yaml unchanged"
      base_sops (read_file (repo // ".sops.yaml")))

let test_cleanup_on_upload_failure () =
  with_sandbox (fun ~repo ~key_file ~remote_tmp ->
    Unix.putenv "FAIL_UPLOAD" "1";
    Alcotest.(check bool) "fails when upload fails"
      true (fails (fun () -> Enroll.enroll ~repo "syd"));
    Alcotest.(check (list string)) "temp key file removed by finally"
      [] (entries (Filename.dirname key_file));
    Alcotest.(check (list string)) "nothing staged in remote /tmp"
      [] (entries remote_tmp);
    Alcotest.(check bool) "no key installed"
      false (Sys.file_exists key_file);
    Alcotest.(check string) ".sops.yaml unchanged"
      base_sops (read_file (repo // ".sops.yaml")))

let () =
  Alcotest.run "ss" [
    "patch_sops", [
      Alcotest.test_case "append aligned anchor and reject duplicate" `Quick test_patch_append;
      Alcotest.test_case "prefix host, comments, and missing section" `Quick test_patch_prefix_and_comments;
    ];
    "enroll", [
      Alcotest.test_case "fresh enroll and reject repeat" `Quick test_enroll_fresh;
      Alcotest.test_case "reject existing remote key" `Quick test_reject_existing_remote_key;
      Alcotest.test_case "cleanup temp key on failure" `Quick test_cleanup_on_upload_failure;
    ];
  ]
