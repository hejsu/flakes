# profiles/user/suspen -- identity & access for this user
{ pkgs, ... }:
let
  mainKey = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBNhZOawFtfii6oSbLM/q8KMfl8u2K9e6R2F8JeeKuIvmJnS8i7BlzocvN8/p3bE/rL6Z+9wi12rWZJCG/Ge6l+Y= main-key@secretive.rhayader.local";
in
{
  user.name = "suspen";

  home.impure.enable = true;

  user.shell = pkgs.fish;

  user.openssh.authorizedKeys.keys = [ mainKey ];
  users.users.root.openssh.authorizedKeys.keys = [ mainKey ];
}


