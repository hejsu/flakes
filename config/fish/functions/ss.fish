function ss --description "Helper for managing dotfiles"
    set -q NH_FLAKE[1]; or set -gx NH_FLAKE $HOME/.config/dotfiles

    set -l cmd $argv[1]
    set -e argv[1]

    switch $cmd
        case '' sync s
            ss_sync $argv
        case swap sw impure
            hjem-impure
        case unswap relink
            ss_unswap
        case gc
            ss_gc $argv
        case pull
            nix flake update --flake $NH_FLAKE $argv
        case gens generations
            ss_gens $argv
        case repl
            nix repl --extra-experimental-features 'flakes repl-flake' --impure $NH_FLAKE $argv
        case path
            ss_path $argv
        case deploy
            ss_deploy $argv
        case help -h --help
            ss_help
        case '-*'
            ss_sync $cmd $argv
        case "*"
            # A bare host name is deploy shorthand: `ss echo` == `ss deploy echo`.
            # Derived from hosts/ so new machines need no edit here. The local
            # host is excluded because rebuilding it is what `ss sync` does.
            if test -d $NH_FLAKE/hosts/$cmd; and test "$cmd" != (hostname -s)
                ss_deploy $cmd $argv
            else
                nh $cmd $argv
            end
    end
end

function ss_help --description "Show ss usage"
    echo 'ss - dotfiles helper

Usage: ss [command] [args...]

Commands:
  sync|s [verb] [args]   Rebuild this host via nh (default verb: switch)
  swap|sw                Swap store links for mutable copies
  unswap|relink          Restore store links (re-runs the hjem agent)
  gc [-u] [-d] [-D] [-n] Clean profiles and optimise the store
  pull [inputs...]       Update flake inputs
  gens                   List system generations
  repl [args]            Open a nix repl with the flake preloaded
  path [area] [rest...]  Print a path inside the repo
  deploy <host...>       Push this checkout to host(s) and rebuild
  <host> [args]          Shorthand for "ss deploy <host>"
  help|-h|--help         Show this help

sync passes its verb straight to nh, so any nh subcommand works:
  switch  build  test  boot  rollback  repl  info  build-vm  build-image
  (nh darwin only ships switch, build and repl; rollback uses darwin-rebuild)

Anything else is passed through to nh.'
end

function ss_sync --description "Rebuild this host via nh (default verb: switch)"
    # A leading flag means the verb was omitted, so `ss --dry` == `ss sync --dry`.
    set -l verb switch
    if set -q argv[1]; and not string match -qr '^-' -- $argv[1]
        set verb $argv[1]
        set -e argv[1]
    end

    ss_require_clean; or return 1

    if test (uname -s) != Darwin
        nh os $verb $argv
        return
    end

    # nh darwin has no rollback, and only switch elevates -- which is what
    # triggers the .cache bug handled by ss_nh_in_scratch.
    switch $verb
        case rollback
            sudo darwin-rebuild --rollback $argv
        case switch
            ss_nh_in_scratch darwin switch $argv
        case '*'
            nh darwin $verb $argv
    end
end

function ss_require_clean --description "Abort when mutable copies would be clobbered"
    # Activation relinks impure copies into the store, so rebuilding or syncing
    # over the checkout silently drops in-place edits. A host only changes which
    # shell runs the check.
    set -l check 'cat "$HOME/.local/state/HJEM_IMPURE_ACTIVE" 2>/dev/null'
    set -l cmd sh -c $check
    set -q argv[1]; and set cmd ssh $argv[1] $check
    set -l state ($cmd)
    test "$state" = 1; or return 0

    set -l where
    set -q argv[1]; and set where " on $argv[1]"
    set -l hint (string join -- ' ' ss unswap $argv[1])
    printf '%s\n' \
        "ss: impure mode is active$where" \
        "  activation would replace your mutable copies with store links." \
        "  run '$hint' first, or copy out the edits you want to keep." >&2
    return 1
end

function ss_gens --description "List system generations"
    if test (uname -s) = Darwin
        # The system profile is root-owned and nix-env needs its lock file to
        # enumerate generations, so this has to elevate. Read-only otherwise.
        sudo darwin-rebuild --list-generations
    else
        nh os info $argv
    end
end

function ss_nh_in_scratch --description "Run nh from a throwaway cwd (nh <= 4.4.2 .cache bug)"
    # TODO(nh): drop once pkgs.nh >= 4.5.0.
    # nh <= 4.4.2 sets HOME="" when elevating, so `nh darwin switch` drops a
    # root-owned .cache in the cwd and later builds hit "Permission denied"
    # (issues/739, fixed in PR 758 / v4.5.0-beta1). The cd happens in a child
    # shell so Ctrl-C cannot strand this shell, and one fixed path is reused:
    # a root-owned .cache cannot be removed as the user, so mktemp would leak
    # one directory per interrupted attempt.
    set -l scratch $TMPDIR/nh-switch.$USER
    test -n "$TMPDIR"; or set scratch /tmp/nh-switch.$USER
    rm -rf $scratch 2>/dev/null
    mkdir -p $scratch
    command fish --no-config -c 'cd $argv[1]; and nh $argv[2..-1]' $scratch $argv
    set -l ret $status
    rm -rf $scratch 2>/dev/null
    return $ret
end

function ss_unswap --description "Restore store symlinks by re-running the hjem activation agent"
    echo "Re-linking hjem files to the store (local swapped copies will be replaced)..."
    if test (uname -s) = Darwin
        launchctl kickstart -k gui/(id -u)/org.hjem.activate
    else
        # NixOS: activation runs as a system unit (org.hjem.activate is darwin-only).
        sudo systemctl start hjem-activate@(id -un).service
    end
end

function ss_gc --description "Clean profiles and optimise the store"
    argparse -i 'u/user' 'd/delete-old' 'D/delete-all-old' 'n/dry' -- $argv; or return 1
    set -l args all --optimise
    set -q _flag_user; and set args[1] user
    set -q _flag_dry; and set -a args --dry
    if set -q _flag_delete_all_old
        set -a args --keep 1
    else if set -q _flag_delete_old
        set -a args --keep-since 14d
    end
    nh clean $args $argv
end

function ss_path --description "Print a path inside the dotfiles repo"
    set -l area $argv[1]
    set -l base
    switch $area
        case '' home flake
            set base $NH_FLAKE
        case config hosts lib modules overlays packages profiles
            set base $NH_FLAKE/$area
        case bin
            set base $NH_FLAKE/config/bin
        case host
            set base $NH_FLAKE/hosts/(hostname -s)
        case profile
            set base /nix/var/nix/profiles/system
        case '*'
            echo "ss path: unknown area '$area'" >&2
            return 1
    end
    set -l rest (string join -- / $argv[2..-1])
    test -n "$rest"; and set rest /$rest
    # Quoted: concatenating an empty list unquoted would drop the whole word.
    echo "$base$rest"
end

function ss_deploy --description "Push this checkout to host(s) and rebuild"
    set -q argv[1]; or begin
        echo "Usage: ss deploy <host...>" >&2
        return 1
    end

    # ~/.ssh/config multiplexes rsync and ssh, but nh prepends its own
    # ControlPath on the command line, which outranks the config; NH_SSHOPTS is
    # put before those defaults, so this keeps nh on the same socket.
    set -l sockets $HOME/.ssh/sockets
    mkdir -p -m 700 $sockets
    set -lx NH_SSHOPTS "-o ControlPath=$sockets/%r@%k:%p"

    for host in $argv
        set host (string trim -- $host)
        test -n "$host"; or continue
        if string match -qr '^-' -- $host
            echo "ss deploy: '$host' looks like a flag; pass host names only" >&2
            return 1
        end

        echo "==> Deploying to $host..."
        ss_ssh_session $host; or return 1
        ss_require_clean $host; or return 1

        rsync -az --delete \
            --exclude .git --exclude .cache --exclude .direnv --exclude 'result*' \
            "$NH_FLAKE/" "$host:.config/dotfiles/"
        # Evaluate locally, build and activate on the target; pure evaluation
        # yields the same drv the target would, so only the work moves.
        #
        # --diff never: `auto` has nh ask the target for its current system, and
        # nix runs each of those queries as a separate `ssh -S none` -- three
        # more authentications on every deploy.
        and nh os switch -H (string replace -r '^.*@' '' -- $host) --diff never \
            --build-host $host --target-host $host
        # TODO(nh): drop once pkgs.nh includes PR 793 (nix-community/nh#793).
        # nh 4.4.2 queries `nix build <drv>^* --print-out-paths` on the remote
        # without `--no-link`, leaving a spurious ~/result symlink on build_host.
        and ssh $host 'rm -f ~/result'
        or begin
            echo "==> Deploy to $host failed!" >&2
            return 1
        end
    end
end

function ss_ssh_session --description "Open the shared SSH master for a deploy"
    # ~/.ssh/config persists for 60s, which a local evaluation outlives: the
    # master dies mid-deploy and every later step authenticates again. One asked
    # for here lives for 30 minutes. No -M on purpose: -M refuses an existing
    # master ("disabling multiplexing") and opens a second, unshared one, while
    # ControlMaster=auto makes this a no-op when a master is already up.
    #
    # Stdio is detached because the backgrounded master outlives this call and
    # would otherwise keep the caller's stdout open: `ss deploy | tee log` would
    # hang until ControlPersist expired.
    set -l err (mktemp)
    ssh -fN -o ControlPersist=30m $argv[1] </dev/null >/dev/null 2>$err
    set -l rc $status
    test $rc -eq 0; and rm -f $err; and return 0
    cat $err >&2
    rm -f $err
    return $rc
end
