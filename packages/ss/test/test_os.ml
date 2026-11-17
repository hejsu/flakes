open Ss_lib

let ( // ) = Filename.concat
let read p = In_channel.with_open_bin p In_channel.input_all
let raises fn = try ignore (fn ()); false with _ -> true
let entries dir = Sys.readdir dir |> Array.to_list |> List.sort compare
let perm p = (Unix.lstat p).st_perm

let test_tmp_dir () =
  let kept = ref "" in
  Os.with_tmp_dir (fun d ->
      kept := d;
      Alcotest.(check int) "dir is 0700" 0o700 (perm d);
      Sh.run ["mkdir"; "-p"; d // "a/b"];
      Os.write_file (d // "a/b/f") "x");
  Alcotest.(check bool) "removed on return" false (Sys.file_exists !kept);
  (try Os.with_tmp_dir (fun d -> kept := d; Os.write_file (d // "f") "x"; failwith "boom")
   with Failure _ -> ());
  Alcotest.(check bool) "removed on exception" false (Sys.file_exists !kept)

let test_write_file () =
  Os.with_tmp_dir (fun d ->
      let f = d // "f" in
      Os.write_file f "one";
      Alcotest.(check string) "created" "one" (read f);
      Alcotest.(check int) "default 0644" 0o644 (perm f);
      Unix.chmod f 0o600;
      Os.write_file f "two";
      Alcotest.(check string) "replaced" "two" (read f);
      Alcotest.(check int) "keeps existing mode" 0o600 (perm f);
      Os.write_file ~mode:0o640 f "three";
      Alcotest.(check int) "explicit mode" 0o640 (perm f);
      Alcotest.(check (list string)) "no temp leftovers" ["f"] (entries d);
      (* Replaces a symlink itself, never writes through it. *)
      let target = d // "target" and link = d // "link" in
      Os.write_file target "store";
      Unix.symlink target link;
      Os.write_file link "mutable";
      Alcotest.(check string) "symlink target untouched" "store" (read target);
      Alcotest.(check bool) "link is now a regular file" true ((Unix.lstat link).st_kind = S_REG);
      (* Failure leaves the original and no temp file. *)
      let ro = d // "ro" in
      Sh.run ["mkdir"; ro];
      Os.write_file (ro // "g") "orig";
      Unix.chmod ro 0o555;
      Fun.protect ~finally:(fun () -> Unix.chmod ro 0o755) (fun () ->
          Alcotest.(check bool) "write into read-only dir fails" true
            (raises (fun () -> Os.write_file (ro // "g") "new")));
      Alcotest.(check string) "original intact" "orig" (read (ro // "g"));
      Alcotest.(check (list string)) "no temp in ro dir" ["g"] (entries ro))


let () =
  Alcotest.run "os" [
    "os", [
      Alcotest.test_case "with_tmp_dir cleanup" `Quick test_tmp_dir;
      Alcotest.test_case "atomic write_file" `Quick test_write_file;
    ];
  ]
