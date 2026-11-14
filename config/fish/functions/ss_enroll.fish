function ss_enroll --description "Provision the sops age machine key on a remote host"
    set -l host "$argv[1]"
    set -l flake "$NH_FLAKE"
    test -n "$flake"; or set flake $HOME/.config/dotfiles
    set -l hosts "$flake"/hosts/*/default.nix

    set -l error
    if test (count $argv) != 1
        set error "usage: ss enroll <host>"
    else if not contains -- "$flake/hosts/$host/default.nix" $hosts
        set error "no such host '$host'"
    end
    if set -q error[1]
        echo "ss enroll: $error" >&2
        return 1
    end
    set -l changes (git -C "$flake" status --porcelain -- .sops.yaml); or return
    if test -n "$changes"
        echo "ss enroll: commit .sops.yaml first" >&2
        return 1
    end

    set -l work (mktemp -d); or return
    set -l rc 0
    # Root can write inside this private directory without /tmp protected_regular restrictions.
    if set -l staged (ssh "$host" 'mktemp -d /tmp/ss-enroll.XXXXXXXX')
        and string match -qr '^/tmp/ss-enroll\.[A-Za-z0-9]+$' -- "$staged"
        __ss_enroll_write "$host" "$flake" "$work" "$staged"
        set rc $status
        test $rc = 0; or ssh -n "$host" "rm -f -- '$staged/key'; rmdir '$staged' 2>/dev/null"
    else
        set rc $status
        echo "ss enroll: remote staging failed" >&2
    end
    rm -f -- "$work/key" "$work/sops.yaml"
    rmdir "$work"
    return $rc
end

function __ss_enroll_write --argument-names host flake work staged
    age-keygen -o "$work/key"
    and set -l public (age-keygen -y "$work/key")
    or return

    awk -v host="$host" -v key="$public" '
        $1 == "-" && $2 == "&" host { if (!sub(/age1[[:alnum:]]+/, key)) exit 1; found = 1 }
        /^creation_rules:/ && !found { print "  - &" host " " key; found = 1 }
        { print }
        END { if (!found) exit 1 }
    ' "$flake/.sops.yaml" >"$work/sops.yaml"; or begin
        echo "ss enroll: cannot patch .sops.yaml" >&2
        return 1
    end
    # Keep sudo and the rotation prompt on the remote terminal, not key stdin.
    set -l install '
        set -eu
        case $(uname -s) in
            Darwin) key=/var/db/age/keys.txt ;;
            Linux) key=/var/lib/sops-nix/key.txt ;;
            *) echo "ss enroll: unsupported OS" >&2; exit 1 ;;
        esac
        action=enroll
        if [ -e "$key" ]; then
            printf "Rotate %s? [y/N] " "$key" >/dev/tty
            read -r reply </dev/tty
            [ "$reply" = y ] || exit 1
            [ ! -e "$key.old" ] || { echo "ss enroll: $key.old already exists" >&2; exit 1; }
            cp -p "$key" "$key.old"
            action=rotate
        fi
        trap "rm -f -- \"$key.new\"" EXIT
        install -d -m 700 -o 0 -g 0 "${key%/*}"
        install -m 600 -o 0 -g 0 "$1" "$key.new"
        mv -f "$key.new" "$key"
        if [ "$action" = rotate ]; then
            echo "ss enroll: rotated; updatekeys before deploy; backup: $key.old" >&2
        fi
        printf "%s\n" "$action" >"$1"
    '
    # The SSH user cleans up even when sudo never starts the installer.
    set -l session '
        trap "rm -f -- \"$2\"; rmdir \"${2%/*}\"" EXIT
        trap "exit 1" HUP INT TERM
        sudo sh -c "$1" sh "$2" && trap - EXIT
    '
    scp -q "$work/key" "$host:$staged/key"
    and ssh -t "$host" "sh -c '$session' sh '$install' '$staged/key'"
    and set -l action (ssh -n "$host" "cat '$staged/key' && rm -f -- '$staged/key' && rmdir '$staged'")
    or return

    set -l changes (git -C "$flake" status --porcelain -- .sops.yaml); or return
    if test -n "$changes"
        echo "ss enroll: key installed, but .sops.yaml changed; refusing to overwrite it" >&2
        return 1
    end
    mv -- "$work/sops.yaml" "$flake/.sops.yaml"
    and git -C "$flake" --no-pager diff -- .sops.yaml
    and git -C "$flake" commit --quiet --only -m "sops: $action $host" -- .sops.yaml
end
