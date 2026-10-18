# Completions for `ss`. Keep the descriptions in step with ss_help.

function __ss_flake_home --description "Print the dotfiles checkout path"
    set -q NH_FLAKE[1]; and echo $NH_FLAKE; and return
    echo $HOME/.config/dotfiles
end

function __ss_hosts --description "List deployable hosts (this machine excluded)"
    set -l flakeHome (__ss_flake_home)
    set -l here (hostname -s)
    for dir in $flakeHome/hosts/*/
        set -l name (string replace -r '^.*/([^/]+)/$' '$1' -- $dir)
        # Deploying to the machine you are on is what `ss sync` already does.
        test "$name" = "$here"; and continue
        test -f $dir/default.nix; and echo $name
    end
end

function __ss_areas --description "List ss path areas"
    set -l flakeHome (__ss_flake_home)
    printf '%s\n' home host profile bin
    for dir in config hosts lib modules overlays packages profiles
        test -d $flakeHome/$dir; and echo $dir
    end
end

function __ss_verbs --description "List the nh verbs ss can drive here"
    if test (uname -s) = Darwin
        # nh darwin ships switch/build/repl; ss adds rollback via darwin-rebuild.
        printf '%s\n' switch build repl rollback
    else
        printf '%s\n' switch boot test build repl info rollback build-vm build-image
    end
end

function __ss_inputs --description "List top-level flake inputs"
    set -l lock (__ss_flake_home)/flake.lock
    test -r $lock; or return

    # Flatten first: fish's regex has no dotall flag.
    set -l flat (string join ' ' (cat $lock))
    set -l root (string match -r '"root":\s*\{\s*"inputs":\s*\{([^}]*)\}' -- $flat)[2]
    string match -ra '"[a-zA-Z0-9_-]+":' -- $root | string replace -r '^"(.*)":$' '$1'
end

complete -c ss -f

# Verbs. `switch` is spelled `sync` here because that is what ss calls it.
complete -c ss -n __fish_use_subcommand -a sync         -d "Rebuild this host via nh (default verb: switch)"
complete -c ss -n __fish_use_subcommand -a s            -d "Alias for sync"
complete -c ss -n __fish_use_subcommand -a swap         -d "Swap store links for mutable copies"
complete -c ss -n __fish_use_subcommand -a sw           -d "Alias for swap"
complete -c ss -n __fish_use_subcommand -a unswap       -d "Restore store links (re-runs the hjem agent)"
complete -c ss -n __fish_use_subcommand -a relink       -d "Alias for unswap"
complete -c ss -n __fish_use_subcommand -a gc           -d "Clean profiles and optimise the store"
complete -c ss -n __fish_use_subcommand -a pull         -d "Update flake inputs"
complete -c ss -n __fish_use_subcommand -a gens         -d "List system generations"
complete -c ss -n __fish_use_subcommand -a generations  -d "Alias for gens"
complete -c ss -n __fish_use_subcommand -a repl         -d "Open a nix repl"
complete -c ss -n __fish_use_subcommand -a path         -d "Print a path inside the repo"
complete -c ss -n __fish_use_subcommand -a deploy       -d "Push this checkout to host(s) and rebuild"
complete -c ss -n __fish_use_subcommand -a help         -d "Show usage help"

# A bare host name means `ss deploy <host>`.
complete -c ss -n __fish_use_subcommand -a "(__ss_hosts)" -d Host

# sync: the verb is passed straight to nh, then nh's own flags.
complete -c ss -n "__fish_seen_subcommand_from sync s" -a "(__ss_verbs)" -d Verb
complete -c ss -n "__fish_seen_subcommand_from sync s; or __fish_use_subcommand" \
    -s n -l dry -d "Only print actions"
complete -c ss -n "__fish_seen_subcommand_from sync s; or __fish_use_subcommand" \
    -l no-nom -d "Do not use nix-output-monitor"
complete -c ss -n "__fish_seen_subcommand_from sync s; or __fish_use_subcommand" \
    -s a -l ask -d "Ask for confirmation"
complete -c ss -n "__fish_seen_subcommand_from sync s; or __fish_use_subcommand" \
    -s v -l verbose -d "Increase verbosity"

# gc
complete -c ss -n "__fish_seen_subcommand_from gc" -s u -l user           -d "Only this user's profiles"
complete -c ss -n "__fish_seen_subcommand_from gc" -s d -l delete-old     -d "Keep generations from the last 14 days"
complete -c ss -n "__fish_seen_subcommand_from gc" -s D -l delete-all-old -d "Keep only one generation"
complete -c ss -n "__fish_seen_subcommand_from gc" -s n -l dry            -d "Print actions only"

# pull: input names come from flake.lock.
complete -c ss -n "__fish_seen_subcommand_from pull" -a "(__ss_inputs)" -d Input

# path
complete -c ss -n "__fish_seen_subcommand_from path" -a "(__ss_areas)" -d Area

# deploy, and the bare-host form.
complete -c ss -n "__fish_seen_subcommand_from deploy" -a "(__ss_hosts)" -d Host

# help
complete -c ss -n "__fish_seen_subcommand_from help" -a "sync swap unswap gc pull gens repl path deploy" -d Verb
