# profiles/user/suspen -- identity & access for this user
{ ss, pkgs, ... }: {
  user.name = "suspen";

  home.impure.enable = true;

  time.timeZone = "Asia/Shanghai";

  user.shell = pkgs.fish;

  user.openssh.authorizedKeys.keys = [ ss.keys.ss0 ];
  users.users.root.openssh.authorizedKeys.keys = [ ss.keys.ss0 ];
}


