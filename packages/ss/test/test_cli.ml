open Ss_lib

let ( // ) = Filename.concat
let ss_bin = Unix.realpath (Filename.dirname Sys.executable_name // "../src/main.exe")
let cli_error = 124
let read_file p = In_channel.with_open_bin p In_channel.input_all

let write_file ?mode path content =
  let perm = Option.value mode ~default:0o644 in
  Out_channel.with_open_gen [Open_wronly; Open_creat; Open_trunc; Open_binary] perm path
    (fun oc -> Out_channel.output_string oc content);
  Option.iter (Unix.chmod path) mode

let run_ss ?stdout_file args =
  let null = Unix.openfile "/dev/null" [O_RDWR; O_CLOEXEC] 0 in
  let out_fd =
    match stdout_file with
    | None -> null
    | Some p -> Unix.openfile p [O_WRONLY; O_CREAT; O_TRUNC; O_CLOEXEC] 0o600
  in
  Fun.protect
    ~finally:(fun () ->
      if out_fd <> null then Unix.close out_fd;
      Unix.close null)
    (fun () ->
      let pid = Unix.create_process ss_bin (Array.of_list ("ss" :: args)) null out_fd null in
      match snd (Unix.waitpid [] pid) with
      | Unix.WEXITED n -> n
      | _ -> 255)

let with_sandbox
    ?(os = "Linux")
    ?(host = "rhayader")
    ?(hosts = "az echo hws rhayader syd")
    ?(inputs = "darwin hjem llm-agents nix-index-database nixpkgs sops-nix")
    fn =
  let root = Filename.temp_dir "ss-cli-" "" in
  Fun.protect ~finally:(fun () -> ignore (Sh.ok ["rm"; "-rf"; root])) @@ fun () ->
  let home = root // "home" in
  let repo = home // ".config/dotfiles" in
  let bin = root // "bin" in
  let log = root // "calls.log" in
  Sh.run ["mkdir"; "-p"; home; repo; bin];
  write_file log "";
  let write_stub name body =
    write_file ~mode:0o755 (bin // name) ("#!/bin/sh\n" ^ body)
  in
  write_stub "uname" (Printf.sprintf "echo %s\n" os);
  write_stub "id" "case \"$1\" in -u) echo 501 ;; -un) echo suspen ;; esac\n";
  write_stub "nh"
    (Printf.sprintf
       "printf '%%s' \"$NH_SSHOPTS\" > %s\nprintf 'nh%%s\\n' \"${1:+ }$*\" >> %s\n"
       (root // "nh_sshopts") log);
  List.iter
    (fun cmd ->
      write_stub cmd (Printf.sprintf "printf '%s%%s\\n' \"${1:+ }$*\" >> %s\n" cmd log))
    ["sudo"; "hjem-impure"; "launchctl"; "nix"];
  write_stub "ssh"
    (Printf.sprintf
       "case \"$*\" in\n\
       \  *HJEM_IMPURE_ACTIVE*) printf '%%s' \"$REMOTE_IMPURE\"; exit 0 ;;\n\
        esac\n\
        printf 'ssh %%s\\n' \"$*\" >> %s\n"
       log);
  let keys =
    ["PATH"; "HOME"; "NH_FLAKE"; "SS_HOST"; "SS_HOSTS"; "SS_INPUTS"; "NH_SSHOPTS"; "REMOTE_IMPURE"]
  in
  let saved = List.map (fun k -> k, Sys.getenv_opt k) keys in
  let orig_path = match Sys.getenv_opt "PATH" with Some p when p <> "" -> ":" ^ p | _ -> "" in
  List.iter (fun (k, v) -> Unix.putenv k v) [
    "PATH", bin ^ orig_path;
    "HOME", home;
    "NH_FLAKE", repo;
    "SS_HOST", host;
    "SS_HOSTS", hosts;
    "SS_INPUTS", inputs;
    "NH_SSHOPTS", "";
    "REMOTE_IMPURE", "";
  ];
  Fun.protect
    ~finally:(fun () ->
      List.iter (fun (k, v) -> Unix.putenv k (Option.value v ~default:"")) saved)
    (fun () ->
      let calls () =
        read_file log |> String.split_on_char '\n' |> List.filter (( <> ) "")
      in
      let clear_calls () = write_file log "" in
      fn ~root ~home ~repo ~bin ~calls ~clear_calls)

let test_path () =
  with_sandbox ~host:"rhayader" (fun ~root ~home:_ ~repo ~bin:_ ~calls:_ ~clear_calls:_ ->
    let out = root // "path.out" in
    let check_path label args expected =
      Alcotest.(check int) (label ^ " exit") 0 (run_ss ~stdout_file:out ("path" :: args));
      Alcotest.(check string) label expected (String.trim (read_file out))
    in
    check_path "default flake root" [] repo;
    check_path "bin area" ["bin"] (repo ^ "/config/bin");
    check_path "host area uses SS_HOST" ["host"; "default.nix"] (repo ^ "/hosts/rhayader/default.nix");
    check_path "modules subpath" ["modules"; "shell"; "fish.nix"] (repo ^ "/modules/shell/fish.nix");
    check_path "system profile" ["profile"] "/nix/var/nix/profiles/system";
    Alcotest.(check int) "unknown area rejected by enum" cli_error (run_ss ["path"; "nope"]))

let test_sync_and_rollback_linux () =
  with_sandbox ~os:"Linux" (fun ~root:_ ~home ~repo:_ ~bin:_ ~calls ~clear_calls ->
    Alcotest.(check int) "bare ss runs default sync" 0 (run_ss []);
    Alcotest.(check int) "unknown subcommand rejected" cli_error (run_ss ["deplo"]);
    Alcotest.(check int) "sync positional arg rejected" cli_error (run_ss ["sync"; "build"]);
    Alcotest.(check int) "sync -nv --no-nom" 0 (run_ss ["sync"; "-nv"; "--no-nom"]);
    Alcotest.(check int) "rollback default" 0 (run_ss ["rollback"]);
    Alcotest.(check int) "rollback 42" 0 (run_ss ["rollback"; "42"]);
    Alcotest.(check int) "rollback non-int rejected" cli_error (run_ss ["rollback"; "prev"]);
    Alcotest.(check (list string)) "linux sync and rollback commands"
      [
        "nh os switch";
        "nh os switch --dry --verbose --no-nom";
        "nh os rollback";
        "nh os rollback --to 42";
      ]
      (calls ());
    clear_calls ();
    let impure = home // ".local/state/HJEM_IMPURE_ACTIVE" in
    Sh.run ["mkdir"; "-p"; Filename.dirname impure];
    write_file impure "1\n";
    Alcotest.(check int) "blocks sync when impure active" 1 (run_ss ["sync"]);
    Alcotest.(check int) "blocks rollback when impure active" 1 (run_ss ["rollback"]);
    Alcotest.(check (list string)) "nothing called when impure" [] (calls ()))

let test_sync_and_rollback_darwin () =
  with_sandbox ~os:"Darwin" (fun ~root ~home:_ ~repo:_ ~bin ~calls ~clear_calls:_ ->
    let cwd_file = root // "nh_cwd" in
    write_file ~mode:0o755 (bin // "nh")
      (Printf.sprintf
         "#!/bin/sh\n[ \"$2\" = switch ] && pwd > %s\nprintf 'nh%%s\\n' \"${1:+ }$*\" >> %s\n"
         cwd_file (root // "calls.log"));
    Alcotest.(check int) "darwin switch -a" 0 (run_ss ["sync"; "-a"]);
    Alcotest.(check int) "darwin rollback" 0 (run_ss ["rollback"]);
    Alcotest.(check int) "darwin rollback 18" 0 (run_ss ["rollback"; "18"]);
    let nh_cwd = String.trim (read_file cwd_file) in
    Alcotest.(check bool) "scratch dir cleaned after switch"
      false (Sys.file_exists nh_cwd);
    Alcotest.(check (list string)) "darwin sync and rollback commands"
      [
        "nh darwin switch --ask";
        "sudo darwin-rebuild --rollback";
        "sudo darwin-rebuild --switch-generation 18";
      ]
      (calls ()))

let test_gc_pull_and_impure () =
  with_sandbox ~os:"Darwin" (fun ~root:_ ~home:_ ~repo ~bin:_ ~calls ~clear_calls:_ ->
    Alcotest.(check int) "gc default keeps 3" 0 (run_ss ["gc"]);
    Alcotest.(check int) "gc -u -k 1 -K 14d -na" 0 (run_ss ["gc"; "-u"; "-k"; "1"; "-K"; "14d"; "-na"]);
    Alcotest.(check int) "gc keep < 1 rejected" 1 (run_ss ["gc"; "-k"; "0"]);
    Alcotest.(check int) "gc unknown flag rejected" cli_error (run_ss ["gc"; "--extra"]);
    Alcotest.(check int) "pull empty rejected" cli_error (run_ss ["pull"]);
    Alcotest.(check int) "pull -a with input rejected" cli_error (run_ss ["pull"; "-a"; "llm-agents"]);
    Alcotest.(check int) "pull unknown input rejected" 1 (run_ss ["pull"; "bogus"]);
    Alcotest.(check int) "pull specific inputs" 0 (run_ss ["pull"; "llm-agents"; "hjem"]);
    Alcotest.(check int) "pull --all" 0 (run_ss ["pull"; "--all"]);
    Alcotest.(check int) "unswap" 0 (run_ss ["unswap"]);
    Alcotest.(check (list string)) "gc, pull, and unswap commands"
      [
        "nh clean all --optimise --keep 3";
        "nh clean user --optimise --keep 1 --keep-since 14d --dry --ask";
        "nix flake update --flake " ^ repo ^ " llm-agents hjem";
        "nix flake update --flake " ^ repo;
        "launchctl kickstart -k gui/501/org.hjem.activate";
      ]
      (calls ()))

let test_deploy () =
  with_sandbox ~host:"rhayader" (fun ~root ~home ~repo:_ ~bin:_ ~calls ~clear_calls ->
    Alcotest.(check int) "empty deploy rejected" cli_error (run_ss ["deploy"]);
    Alcotest.(check int) "leading flag rejected" cli_error (run_ss ["deploy"; "--dry"]);
    Alcotest.(check int) "user@host rejected" 1 (run_ss ["deploy"; "root@echo"]);
    Alcotest.(check int) "deploy echo" 0 (run_ss ["deploy"; "echo"]);
    Alcotest.(check int) "sockets dir 0700"
      0o700 (Unix.stat (home // ".ssh/sockets")).st_perm;
    Alcotest.(check string) "NH_SSHOPTS passed to nh"
      ("-o ControlPath=" ^ (home // ".ssh/sockets") ^ "/%r@%k:%p")
      (read_file (root // "nh_sshopts"));
    Alcotest.(check (list string)) "deploy sequence"
      [
        "nh os switch -H echo --diff never --build-host echo --target-host echo";
        "ssh -n echo rm -f ~/result";
      ]
      (calls ());
    clear_calls ();
    Unix.putenv "REMOTE_IMPURE" "1";
    Alcotest.(check int) "remote impure aborts deploy" 1 (run_ss ["deploy"; "echo"]);
    Alcotest.(check (list string)) "no switch when remote impure" [] (calls ()))

let () =
  Alcotest.run "ss-cli" [
    "path", [
      Alcotest.test_case "resolve areas and enum guard" `Quick test_path;
    ];
    "sync & rollback", [
      Alcotest.test_case "linux sync, rollback, and impure guard" `Quick test_sync_and_rollback_linux;
      Alcotest.test_case "darwin scratch cwd and rollback" `Quick test_sync_and_rollback_darwin;
    ];
    "gc, pull & impure", [
      Alcotest.test_case "gc flags, pull xor/inputs, and unswap" `Quick test_gc_pull_and_impure;
    ];
    "deploy", [
      Alcotest.test_case "deploy sequence and cmdliner guards" `Quick test_deploy;
    ];
  ]
