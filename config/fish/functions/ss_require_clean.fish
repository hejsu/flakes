function ss_require_clean --description "Abort when mutable copies would be clobbered"
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
