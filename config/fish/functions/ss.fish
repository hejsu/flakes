function ss --description "Helper for managing dotfiles"
    set -q NH_FLAKE[1]; or set -gx NH_FLAKE $HOME/.config/dotfiles
    switch "$argv[1]"
        case -h --help
            # Handled by dotfiles ss; `command ss -h` reaches iproute2 ss.
        case '-*'
            command ss $argv
            return
    end
    if set -q SS_BIN[1]; and test -x "$SS_BIN"
        "$SS_BIN" $argv
    else
        nix run "path:$NH_FLAKE#ss" -- $argv
    end
end
