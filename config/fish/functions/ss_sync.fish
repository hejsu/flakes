function ss_sync --description "Rebuild this host via nh (default verb: switch)"
    # A leading flag after `sync` means the verb was omitted, so
    # `ss sync --dry` == `ss sync switch --dry`.
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

function ss_nh_in_scratch --description "Run nh from a throwaway cwd (nh <= 4.4.2 .cache bug)"
    # WORKAROUND: https://github.com/nix-community/nh/issues/739
    set -l scratch $TMPDIR/nh-switch.$USER
    test -n "$TMPDIR"; or set scratch /tmp/nh-switch.$USER
    rm -rf $scratch 2>/dev/null
    mkdir -p $scratch
    command fish --no-config -c 'cd $argv[1]; and nh $argv[2..-1]' $scratch $argv
    set -l ret $status
    rm -rf $scratch
    return $ret
end
