# profiles/user/suspen -- identity & access for this user
{ self, pkgs, lib, ... }: {
  user.name = "suspen";

  home.impure.enable = true;

  user.shell = pkgs.fish;

  user.openssh.authorizedKeys.keys = [ self.keys.ss0 ];
  users.users.root.openssh.authorizedKeys.keys = [ self.keys.ss0 ];
}


