# profiles/role/workstation.nix
{ lib, ... }: {
  # Keep the normal boot-menu timeout for remote/Hyper-V console recovery.
  boot.loader.systemd-boot.enable = lib.mkDefault true;

  # Interactive machines choose when to discard development closures (ss gc).
  nix.gc.automatic = false;

  # Compress under memory pressure rather than going straight to OOM. Keep
  # server host-specific swap choices out of this role.
  zramSwap.enable = lib.mkDefault true;
  systemd.oomd.enableUserSlices = true;

  # Socket activation applies only when the host enables the SSH server.
  services.openssh.startWhenNeeded = true;
  # The client agent is useful independently of inbound SSH access.
  programs.ssh.startAgent = true;
}
