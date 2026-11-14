function ss_unswap --description "Restore store symlinks by re-running the hjem activation agent"
    echo "Re-linking hjem files to the store (local swapped copies will be replaced)..."
    if test (uname -s) = Darwin
        launchctl kickstart -k gui/(id -u)/org.hjem.activate
    else
        # NixOS: activation runs as a system unit (org.hjem.activate is darwin-only).
        sudo systemctl start hjem-activate@(id -un).service
    end
end
