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
