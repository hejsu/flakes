function fish_right_prompt
    set -q __fish_git_prompt_showdirtystate
    or set -g __fish_git_prompt_showdirtystate 1

    set -q __fish_git_prompt_showuntrackedfiles
    or set -g __fish_git_prompt_showuntrackedfiles 1

    set -q __fish_git_prompt_color_branch
    or set -g __fish_git_prompt_color_branch yellow

    set -q __fish_git_prompt_color_dirtystate
    or set -g __fish_git_prompt_color_dirtystate red

    set -q __fish_git_prompt_color_stagedstate
    or set -g __fish_git_prompt_color_stagedstate green

    set -l git (fish_git_prompt "%s")
    if test -n "$git"
        echo -n "$git ~ "
    end

    echo -n $USER@$hostname
end

