type area =
  | Repo
  | Subdir of string
  | Host
  | Profile

let areas = [
  "home", Repo;
  "flake", Repo;
  "host", Host;
  "profile", Profile;
  "bin", Subdir "config/bin";
  "config", Subdir "config";
  "hosts", Subdir "hosts";
  "lib", Subdir "lib";
  "modules", Subdir "modules";
  "overlays", Subdir "overlays";
  "packages", Subdir "packages";
  "profiles", Subdir "profiles";
]

let resolve ~repo ?(area = Repo) rest =
  let base =
    match area with
    | Repo -> repo
    | Subdir sub -> repo ^ "/" ^ sub
    | Host -> repo ^ "/hosts/" ^ Env.host
    | Profile -> "/nix/var/nix/profiles/system"
  in
  String.concat "/" (base :: rest)
