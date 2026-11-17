open Ss_lib

let big = String.init 1_048_576 (fun i -> Char.chr (i mod 256))
let fails fn = try ignore (fn ()); false with Env.Error _ -> true

let test_stdin () =
  Alcotest.(check string) "small roundtrip" "hi\n" (Sh.read ~stdin:(`String "hi\n") ["cat"]);
  Alcotest.(check string) "1 MiB roundtrip (select, no deadlock)" big (Sh.read ~stdin:(`String big) ["cat"]);
  Alcotest.(check string) "empty string" "" (Sh.read ~stdin:(`String "") ["cat"]);
  Alcotest.(check string) "null stdin" "" (Sh.read ~stdin:`Null ["cat"]);
  Alcotest.(check bool) "stdin reaches run" true
    (Sh.ok ~stdin:(`String "needle") ~stdout:`Null ["grep"; "-q"; "needle"]);
  Alcotest.(check bool) "string stdin with inherited stdout" true
    (Sh.ok ~stdin:(`String big) ~stdout:`Null ["cat"])

let test_epipe () =
  Alcotest.(check bool) "child ignoring 1 MiB stdin is not an error" true
    (Sh.ok ~stdin:(`String big) ["true"]);
  Alcotest.(check string) "partial reader still yields its output" "x"
    (Sh.read ~stdin:(`String big) ["head"; "-c"; "1"] |> String.map (fun _ -> 'x'))

let test_sigpipe () =
  Alcotest.(check bool) "child gets default SIGPIPE despite parent ignoring it" true
    (Sh.run_status ~stdin:(`String "x") ~stdout:`Null ["sh"; "-c"; "kill -PIPE $$; echo alive"]
     = Unix.WSIGNALED Sys.sigpipe);
  let current = Sys.signal Sys.sigpipe Sys.Signal_ignore in
  Alcotest.(check bool) "parent ignores SIGPIPE process-wide" true (current = Sys.Signal_ignore)

let test_cwd () =
  let tmp = Unix.realpath (Filename.get_temp_dir_name ()) in
  let before = Sys.getcwd () in
  Alcotest.(check string) "child runs in ~cwd" tmp (Sh.read ~cwd:tmp ["pwd"; "-P"] |> String.trim);
  Alcotest.(check string) "parent cwd untouched" before (Sys.getcwd ());
  Alcotest.(check bool) "missing ~cwd is Env.Error" true
    (fails (fun () -> Sh.run ~cwd:"/nonexistent-ss-dir" ["true"]));
  Alcotest.(check string) "parent cwd untouched after failure" before (Sys.getcwd ())

let test_resolve () =
  Alcotest.(check bool) "absolute program path" true (Sh.ok ["/bin/sh"; "-c"; "exit 0"]);
  Alcotest.(check string) "lookup honours ~env PATH" "/bin"
    (Sh.read ~env:["PATH", "/bin"] ["sh"; "-c"; "printf %s \"$PATH\""]);
  Alcotest.(check bool) "not on overridden PATH" true
    (fails (fun () -> Sh.run ~env:["PATH", "/nonexistent-ss-dir"] ["sh"; "-c"; "true"]));
  Alcotest.(check bool) "directories are skipped" true
    (fails (fun () -> Sh.run ~env:["PATH", "/"] ["tmp"]))

let test_env () =
  Alcotest.(check string) "adds variable" "v"
    (Sh.read ~env:["SS_T", "v"] ["sh"; "-c"; "printf %s \"$SS_T\""]);
  Alcotest.(check string) "overrides inherited" "/nowhere"
    (Sh.read ~env:["HOME", "/nowhere"] ["sh"; "-c"; "printf %s \"$HOME\""]);
  Alcotest.(check bool) "keeps the rest" true
    (Sh.read ~env:["SS_T", "v"] ["sh"; "-c"; "printf %s \"$PATH\""] <> "")

let test_status () =
  Alcotest.(check bool) "ok true" true (Sh.ok ["true"]);
  Alcotest.(check bool) "ok false" false (Sh.ok ["false"]);
  Alcotest.(check bool) "run raises on exit 1" true (fails (fun () -> Sh.run ["false"]));
  Alcotest.(check bool) "read raises on exit 1" true (fails (fun () -> Sh.read ["false"]));
  Alcotest.(check bool) "missing program" true (fails (fun () -> Sh.run ["ss-no-such-prog"]));
  Alcotest.(check bool) "signal reported" true
    (try Sh.run ["sh"; "-c"; "kill -TERM $$"]; false
     with Env.Error msg -> String.ends_with ~suffix:"killed by SIGTERM" msg)

let test_no_fd_leak () =
  let count () = Array.length (Sys.readdir "/dev/fd") in
  let before = count () in
  for _ = 1 to 30 do
    ignore (Sh.read ~stdin:(`String "x") ~stderr:`Null ["cat"]);
    ignore (Sh.ok ~stdin:(`String big) ["true"]);
    ignore (Sh.ok ~stdin:`Null ~stdout:`Null ~stderr:`Null ["false"]);
    (try Sh.run ~stdin:(`String "x") ["ss-no-such-prog"] with Env.Error _ -> ())
  done;
  Alcotest.(check int) "fd count stable" before (count ())

let () =
  Alcotest.run "sh" [
    "sh", [
      Alcotest.test_case "string stdin" `Quick test_stdin;
      Alcotest.test_case "EPIPE is not an error" `Quick test_epipe;
      Alcotest.test_case "SIGPIPE scoping" `Quick test_sigpipe;
      Alcotest.test_case "per-command cwd" `Quick test_cwd;
      Alcotest.test_case "PATH resolution" `Quick test_resolve;
      Alcotest.test_case "env overrides" `Quick test_env;
      Alcotest.test_case "exit status" `Quick test_status;
      Alcotest.test_case "no fd leak" `Quick test_no_fd_leak;
    ];
  ]
