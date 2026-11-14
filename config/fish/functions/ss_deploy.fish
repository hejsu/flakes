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
        # WORKAROUND: https://github.com/nix-community/nh/pull/793
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
