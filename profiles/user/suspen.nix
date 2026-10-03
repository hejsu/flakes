# profiles/user/suspen -- identity & access for this user
#
# This file only describes *who* the primary user is and how they get in
# (keys, locale/timezone). Software lives in modules/*, not here.
{ ss, lib, pkgs, ... }: {
  user.name = "suspen";

  home.impure.enable = true;

  time.timeZone = "Asia/Shanghai";

  user.openssh.authorizedKeys.keys = [ ss.keys.ss0 ];

  users.users.root.openssh.authorizedKeys.keys =
    lib.mkIf pkgs.stdenv.hostPlatform.isLinux [ ss.keys.ss0 ];

  user.shell = lib.mkIf pkgs.stdenv.hostPlatform.isLinux pkgs.fish;
}


