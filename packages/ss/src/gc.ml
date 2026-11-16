let gc ~user ~keep ~keep_since ~dry ~ask =
  if keep < 1 then failwith "--keep must be >= 1";
  let scope = if user then "user" else "all" in
  let flags =
    ["--optimise"; "--keep"; string_of_int keep]
    @ (match keep_since with Some d -> ["--keep-since"; d] | None -> [])
    @ (if dry then ["--dry"] else [])
    @ (if ask then ["--ask"] else [])
  in
  Sh.run (["nh"; "clean"; scope] @ flags)
