function ss_gens --description "List system generations"
    if test (uname -s) = Darwin
        # The system profile is root-owned and nix-env needs its lock file to
        # enumerate generations, so this has to elevate. Read-only otherwise.
        sudo darwin-rebuild --list-generations
    else
        nh os info $argv
    end
end
