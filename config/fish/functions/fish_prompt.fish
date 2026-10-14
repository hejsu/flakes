function fish_prompt
    set -l symbol '/> '
    if test "$PWD" = "$HOME" -o "$PWD" = /
        set symbol '> '
    end

    echo
    echo -n (prompt_pwd --full-length-dirs 2)

    echo -n "$symbol"
    set_color normal
end
