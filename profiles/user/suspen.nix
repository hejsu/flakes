# profiles/user/suspen -- identity & access for this user
#
# This file only describes *who* the primary user is and how they get in
# (keys, locale/timezone). Software lives in modules/*, not here.
{ ss, pkgs, ... }: {
  user.name = "suspen";

  home.impure.enable = true;

  time.timeZone = "Asia/Shanghai";

  # Access: user and root both trust the same key.
  user.openssh.authorizedKeys.keys = [ ss.keys.ss0 ];
  users.users.root.openssh.authorizedKeys.keys = [ ss.keys.ss0 ];

  # Daily driver shell. root stays on bash on purpose (rescue/logins).
  user.shell = pkgs.fish;
}


