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
            ss_unswap $argv
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
        case enroll
            ss_enroll $argv
        case help -h --help
            ss_help
        case '-*'
            # Leading flags are iproute2 ss (`ss -lntp`), not the helper.
            # Helper sync flags go after the verb: `ss sync --dry`.
            command ss $cmd $argv
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
  enroll <host>          Provision the sops age machine key on a host
  <host> [args]          Shorthand for "ss deploy <host>"
  help|-h|--help         Show this help

sync passes its verb straight to nh, so any nh subcommand works:
  switch  build  test  boot  rollback  repl  info  build-vm  build-image
  (nh darwin only ships switch, build and repl; rollback uses darwin-rebuild)

Anything else is passed through to nh.

Leading flags are passed to iproute2 ss, so `ss -lntp` works. Helper sync
flags go after the verb: `ss sync --dry`. Real ss help is `command ss -h`.'
end
