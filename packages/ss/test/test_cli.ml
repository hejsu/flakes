open Ss_lib

let ( // ) = Filename.concat
let ss_bin = Unix.realpath (Filename.dirname Sys.executable_name // "../src/main.exe")
let cli_error = 124
let some_error = 123
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
    ?(host = "rhayader")
    ?(hosts = "az echo hws syd")
    ?(inputs = "darwin hjem llm-agents nix-index-database nixpkgs sops-nix")
    fn =
  Os.with_tmp_dir ~prefix:"ss-cli-" (fun root ->
      let home = root // "home" in
      let repo = home // ".config/dotfiles" in
      let bin = root // "bin" in
      let log = root // "calls.log" in
      Sh.run ["mkdir"; "-p"; home; repo; bin];
      write_file log "";
      let write_stub name body =
        write_file ~mode:0o755 (bin // name) ("#!/bin/sh\n" ^ body)
      in
      write_stub "nh"
        (Printf.sprintf
           "printf '%%s' \"$NH_SSHOPTS\" > %s\nprintf 'nh%%s\\n' \"${1:+ }$*\" >> %s\n"
           (root // "nh_sshopts") log);
      List.iter
        (fun cmd ->
          write_stub cmd (Printf.sprintf "printf '%s%%s\\n' \"${1:+ }$*\" >> %s\n" cmd log))
        ["sudo"; "launchctl"; "nix"];
      write_stub "ssh"
        (Printf.sprintf
           "case \"$*\" in\n\
           \  *impure.json*) printf '%%s' \"$REMOTE_IMPURE\"; exit 0 ;;\n\
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
          fn ~root ~home ~repo ~bin ~calls ~clear_calls))

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

let test_cli_guards_and_impure () =
  with_sandbox (fun ~root ~home ~repo ~bin:_ ~calls:_ ~clear_calls:_ ->
    Alcotest.(check int) "unknown subcommand rejected" cli_error (run_ss ["deplo"]);
    Alcotest.(check int) "sync positional arg rejected" cli_error (run_ss ["sync"; "build"]);
    Alcotest.(check int) "rollback non-int rejected" cli_error (run_ss ["rollback"; "prev"]);
    Alcotest.(check int) "rollback 0 rejected" cli_error (run_ss ["rollback"; "0"]);
    Alcotest.(check int) "gc keep < 1 rejected" cli_error (run_ss ["gc"; "-k"; "0"]);
    Alcotest.(check int) "gc unknown flag rejected" cli_error (run_ss ["gc"; "--extra"]);
    Alcotest.(check int) "pull empty rejected" cli_error (run_ss ["pull"]);
    Alcotest.(check int) "pull -a with input rejected" cli_error (run_ss ["pull"; "-a"; "llm-agents"]);
    Alcotest.(check int) "pull unknown input rejected" cli_error (run_ss ["pull"; "bogus"]);
    Alcotest.(check int) "empty deploy rejected" cli_error (run_ss ["deploy"]);
    Alcotest.(check int) "user@host rejected" cli_error (run_ss ["deploy"; "root@echo"]);
    Alcotest.(check int) "darwin host rejected" cli_error (run_ss ["deploy"; "rhayader"]);

    (* Disabled host *)
    Alcotest.(check int) "swap fails when disabled" some_error (run_ss ["swap"]);
    Alcotest.(check int) "unswap fails when disabled" some_error (run_ss ["unswap"]);

    match Env.os with
    | Env.Darwin ->
        let store_src = root // "store-source" in
        let store_nvim = store_src // "config/nvim" in
        let store_gen = root // "store-fish-config.fish" in
        let store_state = root // "store-state.json" in
        Sh.run ["mkdir"; "-p"; store_nvim; repo // "config/nvim"; home // ".config/fish"; home // ".local/state"];
        write_file ~mode:0o444 store_gen "# generated fish\n";
        write_file ~mode:0o444 store_state (Printf.sprintf {|{"active":false,"sourceDir":%S}|} store_src);

        let dst_nvim = home // ".config/nvim" in
        let dst_fish = home // ".config/fish/config.fish" in
        let dst_real = home // ".config/real.conf" in
        let dst_state = home // ".local/state/impure.json" in
        Unix.symlink store_nvim dst_nvim;
        Unix.symlink store_gen dst_fish;
        write_file dst_real "keep me\n";
        Unix.symlink store_state dst_state;

        let manifest_dir = home // "Library/Application Support/Hjem" in
        Sh.run ["mkdir"; "-p"; manifest_dir];
        write_file (manifest_dir // "manifest.json")
          (Printf.sprintf
             {|{"version":3,"files":[
                {"type":"symlink","source":%S,"target":%S,"clobber":true},
                {"type":"symlink","source":%S,"target":%S,"clobber":true},
                {"type":"symlink","source":%S,"target":%S,"clobber":true},
                {"type":"symlink","source":%S,"target":%S,"clobber":true}
              ]}|}
             store_nvim dst_nvim
             store_gen dst_fish
             store_gen dst_real
             store_state dst_state);

        Alcotest.(check int) "swap succeeds" 0 (run_ss ["swap"]);
        Alcotest.(check string) "repo symlink redirected" (repo // "config/nvim") (Unix.readlink dst_nvim);
        Alcotest.(check bool) "generated file is regular" true ((Unix.lstat dst_fish).st_kind = Unix.S_REG);
        Alcotest.(check bool) "generated file is writable" true ((Unix.lstat dst_fish).st_perm land 0o200 <> 0);
        Alcotest.(check string) "non-symlink preserved" "keep me\n" (read_file dst_real);
        Alcotest.(check bool) "state marked active"
          true (Yojson.Basic.from_file dst_state |> Impure.state_of_json).active;
        Alcotest.(check int) "blocks sync when impure active" some_error (run_ss ["sync"]);
        Alcotest.(check int) "blocks rollback when impure active" some_error (run_ss ["rollback"]);
        Alcotest.(check int) "second swap is idempotent" 0 (run_ss ["swap"])
    | Env.Linux ->
        let dst_state = home // ".local/state/impure.json" in
        Sh.run ["mkdir"; "-p"; Filename.dirname dst_state];
        write_file dst_state {|{"active":true,"sourceDir":"/nix/store/fake"}|};
        Alcotest.(check int) "blocks sync when impure active" some_error (run_ss ["sync"]);
        Alcotest.(check int) "blocks rollback when impure active" some_error (run_ss ["rollback"]))

let test_remote_impure_guard () =
  with_sandbox (fun ~root:_ ~home:_ ~repo:_ ~bin:_ ~calls ~clear_calls:_ ->
    Unix.putenv "REMOTE_IMPURE" {|{"active":true,"sourceDir":"/nix/store/fake"}|};
    Alcotest.(check int) "remote impure aborts deploy" some_error (run_ss ["deploy"; "echo"]);
    Alcotest.(check (list string)) "no switch when remote impure" [] (calls ()))

let () =
  Alcotest.run "ss-cli" [
    "path", [
      Alcotest.test_case "resolve areas and enum guard" `Quick test_path;
    ];
    "guards & impure", [
      Alcotest.test_case "arg converters and impure swap" `Quick test_cli_guards_and_impure;
      Alcotest.test_case "remote impure deploy guard" `Quick test_remote_impure_guard;
    ];
  ]
