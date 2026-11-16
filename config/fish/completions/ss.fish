# Completions for `ss`.

function __ss_flake_home --description "Print the dotfiles checkout path"
    set -q NH_FLAKE[1]; and echo $NH_FLAKE; and return
    echo $HOME/.config/dotfiles
end

function __ss_hosts --description "List deployable hosts (this machine excluded)"
    set -l here $SS_HOST
    test -n "$here"; or set here (hostname -s)
    if set -q SS_HOSTS[1]
        for name in (string split ' ' -- $SS_HOSTS)
            test "$name" != "$here"; and echo $name
        end
        return
    end
    set -l flakeHome (__ss_flake_home)
    for dir in $flakeHome/hosts/*/
        set -l name (string replace -r '^.*/([^/]+)/$' '$1' -- $dir)
        test "$name" = "$here"; and continue
        test -f $dir/default.nix; and echo $name
    end
end

function __ss_areas --description "List ss path areas"
    set -l flakeHome (__ss_flake_home)
    printf '%s\n' home flake host profile bin
    for dir in config hosts lib modules overlays packages profiles
        test -d $flakeHome/$dir; and echo $dir
    end
end

function __ss_inputs --description "List top-level flake inputs"
    if set -q SS_INPUTS[1]
        string split ' ' -- $SS_INPUTS
        return
    end
    set -l lock (__ss_flake_home)/flake.lock
    test -r $lock; and jq -r '.nodes.root.inputs | keys[]' $lock 2>/dev/null
end

complete -c ss -f

complete -c ss -n __fish_use_subcommand -a sync     -d "Rebuild and activate this host"
complete -c ss -n __fish_use_subcommand -a rollback -d "Roll back to a previous system generation"
complete -c ss -n __fish_use_subcommand -a swap     -d "Swap store links for mutable copies"
complete -c ss -n __fish_use_subcommand -a unswap   -d "Restore store links (re-runs the hjem agent)"
complete -c ss -n __fish_use_subcommand -a gens     -d "List system generations"
complete -c ss -n __fish_use_subcommand -a gc       -d "Clean profiles and optimise the store"
complete -c ss -n __fish_use_subcommand -a pull     -d "Update flake inputs"
complete -c ss -n __fish_use_subcommand -a repl     -d "Open a nix repl"
complete -c ss -n __fish_use_subcommand -a path     -d "Print a path inside the repo"
complete -c ss -n __fish_use_subcommand -a deploy   -d "Rebuild and activate configuration on remote host(s)"
complete -c ss -n __fish_use_subcommand -a enroll   -d "Provision the sops age machine key on a host"

# sync
complete -c ss -n "__fish_seen_subcommand_from sync" -s n -l dry     -d "Only print actions"
complete -c ss -n "__fish_seen_subcommand_from sync"      -l no-nom  -d "Do not use nix-output-monitor"
complete -c ss -n "__fish_seen_subcommand_from sync" -s a -l ask     -d "Ask for confirmation"
complete -c ss -n "__fish_seen_subcommand_from sync" -s v -l verbose -d "Increase verbosity"

# gc
complete -c ss -n "__fish_seen_subcommand_from gc" -s u -l user       -d "Only this user's profiles"
complete -c ss -n "__fish_seen_subcommand_from gc" -s k -l keep       -r -d "Minimum number of generations to keep"
complete -c ss -n "__fish_seen_subcommand_from gc" -s K -l keep-since -r -d "Keep generations newer than duration (e.g. 14d)"
complete -c ss -n "__fish_seen_subcommand_from gc" -s n -l dry        -d "Only print actions"
complete -c ss -n "__fish_seen_subcommand_from gc" -s a -l ask        -d "Ask for confirmation"

# pull
complete -c ss -n "__fish_seen_subcommand_from pull" -s a -l all -d "Update all flake inputs"
complete -c ss -n "__fish_seen_subcommand_from pull; and not __fish_seen_argument -s a -l all" -a "(__ss_inputs)" -d Input

# path
complete -c ss -n "__fish_seen_subcommand_from path" -a "(__ss_areas)" -d Area

# deploy & enroll
complete -c ss -n "__fish_seen_subcommand_from deploy" -a "(__ss_hosts)" -d Host
complete -c ss -n "__fish_seen_subcommand_from enroll" -a "(__ss_hosts)" -d Host
