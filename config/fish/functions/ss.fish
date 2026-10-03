function ss --description "Helper for managing dotfiles"
    set -l flakeHome "$NH_FLAKE"
    if test -z "$flakeHome"
        set flakeHome "$HOME/.config/dotfiles"
    end
    set -x NH_FLAKE $flakeHome

    set -l cmd "$argv[1]"
    set -q argv[1]; and set -e argv[1]

    switch $cmd
        case '' sync
            ss_sync $argv
        case impure swap
            ss_impure
        case unswap relink
            ss_unswap
        case gc
            ss_gc $argv
        case pull
            ss_pull $argv
        case gens generations
            if test (uname -s) = Darwin
                darwin-rebuild --list-generations
            else
                nh os info $argv
            end
        case repl
            ss_repl $argv
        case path
            ss_path $argv
        case az
            ss_deploy_az
        case help -h --help
            ss_help
        case "*"
            nh $cmd $argv
    end
end

function ss_help --description "Show ss usage"
    echo "ss - dotfiles helper"
    echo
    echo "Usage: ss [command] [args...]"
    echo
    echo "Commands:"
    echo "  sync [switch|build|rollback] [args]  Rebuild this host (default: switch)"
    echo "  impure | swap                        Swap hjem files for mutable repo copies"
    echo "  unswap | relink                      Restore store symlinks (re-runs the hjem agent)"
    echo "  gc [-u] [-d] [-D] [-n] [args]        Clean profiles and optimise the store"
    echo "  pull [inputs...]                     Update flake inputs"
    echo "  gens                                 List system generations"
    echo "  repl [args]                          Open a nix repl with the flake preloaded"
    echo "  path [area] [segments...]            Print a path inside the repo"
    echo "  az                                   Sync the repo to az and rebuild there"
    echo "  help, -h, --help                     Show this help"
    echo
    echo "Anything else is passed through to nh."
end

function ss_sync --description "Rebuild this host: switch (default), build, rollback"
    set -l action "$argv[1]"
    set -q argv[1]; and set -e argv[1]
    echo "> "(hostname -s)" ("(uname -sm)")"
    switch $action
        case '' switch
            ss_switch $argv
        case build
            ss_build $argv
        case rollback
            ss_rollback $argv
        case '-*'
            ss_switch $action $argv
        case "*"
            echo "ss sync: unknown action '$action' (switch|build|rollback)" >&2
            return 1
    end
end

function ss_switch --description "nh switch for the local platform"
    if test (uname -s) = Darwin
        set -l tmpdir (mktemp -d)
        pushd $tmpdir >/dev/null
        nh darwin switch $argv
        set -l ret $status
        popd >/dev/null
        rm -rf $tmpdir 2>/dev/null
        return $ret
    end
    nh os switch $argv
end

function ss_build --description "nh build for the local platform"
    if test (uname -s) = Darwin
        nh darwin build $argv
    else
        nh os build $argv
    end
end

function ss_rollback --description "Roll back the system generation"
    if test (uname -s) = Darwin
        sudo darwin-rebuild --rollback $argv
        return $status
    end
    nh os rollback $argv
end

function ss_impure --description "Swap hjem files for mutable repo copies (hjem-impure)"
    hjem-impure
end

function ss_unswap --description "Restore store symlinks by re-running the hjem agent"
    echo "Re-linking hjem files to the store (local swapped copies will be replaced)..."
    launchctl kickstart -k gui/(id -u)/org.hjem.activate
end

function ss_gc --description "Clean profiles and optimise the store"
    argparse --ignore-unknown 'u/user' 'd/delete-old' 'D/delete-all-old' 'n/dry' -- $argv
    or return 1
    set -l mode all
    set -q _flag_user; and set mode user
    set -l extra
    set -q _flag_dry; and set -a extra --dry
    set -q _flag_delete_old; and set -a extra --keep-since 14d
    set -q _flag_delete_all_old; and set -a extra --keep 1
    nh clean $mode --optimise $extra $argv
end

function ss_pull --description "Update flake inputs (all, or a subset)"
    if test (count $argv) -eq 0
        nix flake update --flake $NH_FLAKE
    else
        nix flake update --flake $NH_FLAKE $argv
    end
end

function ss_repl --description "Open a nix repl with the flake preloaded"
    nix repl --extra-experimental-features 'flakes repl-flake' --impure $NH_FLAKE $argv
end

function ss_path --description "Print a path inside the dotfiles repo"
    set -l area $argv[1]
    set -l rest $argv[2..-1]
    set -l base
    switch $area
        case '' home flake
            set base $NH_FLAKE
        case config
            set base $NH_FLAKE/config
        case bin
            set base $NH_FLAKE/config/bin
        case hosts
            set base $NH_FLAKE/hosts
        case host
            set base $NH_FLAKE/hosts/(hostname -s)
        case lib modules overlays packages profiles
            set base $NH_FLAKE/$area
        case profile
            set base /nix/var/nix/profiles/system
        case "*"
            echo "ss path: unknown area '$area'" >&2
            return 1
    end
    set -l suffix (string join / $rest)
    if test -n "$suffix"
        echo $base/$suffix
    else
        echo $base
    end
end

function ss_deploy_az --description "Sync dotfiles to az and rebuild there"
    set -l host az
    set -l dir /home/suspen/.config/dotfiles
    rsync -az --delete \
        --exclude .git --exclude .cache --exclude .direnv --exclude 'result*' \
        "$NH_FLAKE/" "$host:$dir/"
    and ssh -t $host "sudo nixos-rebuild switch --flake $dir#az"
end
