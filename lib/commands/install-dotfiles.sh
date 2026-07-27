#!/usr/bin/env bash

# shellcheck disable=2154

# TODO: Check if this function is fully verbosified.
install_dotfiles() {
    local srcdir
    sprint "Installing dotfiles."

    # Mainly for my convenience.
    if [ -d "/home/$username/rp/dotfiles" ]; then
        sprint "Found local dotfiles."
        srcdir="/home/$username/rp/dotfiles/"
    else
        local repo_dir

        sprint "Cloning or updating remote repository."
        repo_dir="/home/$username/.local/src/$dotfiles_name"

        sync_git_repo "$username" "$dotfiles_url" "$repo_dir"

        srcdir="$repo_dir/"
    fi

    sudo -u "$username" rsync -a "$srcdir" "/home/$username"

    # Remove extra files
    rm "/home/$username/.gitignore" "/home/$username/.gitmodules" "/home/$username/LICENSE" "/home/$username/README.md"

    rm -rf "/home/$username/.git"

    # Symbolic links to useful applications
    [ -f /opt/v2rayn-bin/v2rayN ] && sudo -u "$username" ln -sf /opt/v2rayn-bin/v2rayN "/home/$username/.local/bin/v2rayn"
}


command_install_dotfiles() {
    isRoot && wheel_can_sudo
    ask_username
    install_essentials || eprint "Could not install essential programs.\nHint: Run as root."
    install_dotfiles
    exit 0
}
