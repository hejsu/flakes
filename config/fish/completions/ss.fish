function __ss_hosts
    set -l flakeHome "$NH_FLAKE"
    test -z "$flakeHome"; and set flakeHome "$HOME/.config/dotfiles"
    if test -d "$flakeHome/hosts"
        command ls -1 "$flakeHome/hosts" 2>/dev/null
    end
end

complete -c ss -f
complete -c ss -n "__fish_use_subcommand" -a sync -d "Rebuild this host (switch|build|rollback)"
complete -c ss -n "__fish_use_subcommand" -a deploy -d "Sync dotfiles to remote host(s) and rebuild"
complete -c ss -n "__fish_use_subcommand" -a impure -d "Swap hjem files for mutable repo copies"
complete -c ss -n "__fish_use_subcommand" -a unswap -d "Restore store symlinks"
complete -c ss -n "__fish_use_subcommand" -a gc -d "Clean profiles and optimise the store"
complete -c ss -n "__fish_use_subcommand" -a pull -d "Update flake inputs"
complete -c ss -n "__fish_use_subcommand" -a gens -d "List system generations"
complete -c ss -n "__fish_use_subcommand" -a repl -d "Open a nix repl"
complete -c ss -n "__fish_use_subcommand" -a path -d "Print a path inside the repo"
complete -c ss -n "__fish_use_subcommand" -a az -d "Alias for 'ss deploy az'"
complete -c ss -n "__fish_use_subcommand" -a help -d "Show usage help"

# Subcommand: sync
complete -c ss -n "__fish_seen_subcommand_from sync" -a "switch build rollback"

# Subcommand: deploy
complete -c ss -n "__fish_seen_subcommand_from deploy" -a "(__ss_hosts)" -d "Host"

