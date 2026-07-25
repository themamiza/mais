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
        sprint "Cloning remote repository."
        srcdir="/home/$username/.local/src/$dotfiles_name/"
        sudo -u "$username" mkdir -p "/home/$username/.local/src"
        sudo -u "$username" sh -c "git clone --depth 1 --single-branch --no-tags $dotfiles_url /home/$username/.local/src/$dotfiles_name $cmd_suffix" ||
            {
                cd "/home/$username/.local/src/$dotfiles_name" || exit 1
                sudo -u "$username" sh -c "git pull --force origin master $cmd_suffix"
            }
        cd "/home/$username/.local/src/$dotfiles_name" || exit 1
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
