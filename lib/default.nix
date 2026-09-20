{ lib, ... }:

lib.extend (self: super:
let
  host = import ./host.nix { lib = self; };
  modules = import ./modules.nix { lib = self; };
  system = import ./system.nix { lib = self; };
in
host // modules // system
)
