function fish_prompt
    set -l last_status $status

    set -l symbol '/> '
    if test "$PWD" = "$HOME" -o "$PWD" = /
        set symbol '> '
    end

    set -l color_cwd $fish_color_cwd
    if fish_is_root_user
        set color_cwd $fish_color_cwd_root
    end

    echo
    echo -n (prompt_pwd --full-length-dirs 2)

    echo -n "$symbol"
    set_color normal
end
