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
