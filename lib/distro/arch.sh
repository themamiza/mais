#!/usr/bin/env bash

# shellcheck disable=2154

# Checks a given name against both the executable and package names.
check_installed() {
    # Check if a command is available.
    command -v "$1" >/dev/null 2>&1 && return 0
    # Check if a package is available.
    pacman -Q "$1" >/dev/null 2>&1 && return 0
    # Return false otherwise.
    return 1
}

pacman_install() {
    nprint "Installing $1 -> $2"
    eval "pacman -S --noconfirm '$1' $cmd_suffix"
}

aur_install() {
    nprint "Installing $1 -> $2"
    sudo -u "$username" sh -c "$aurhelper -S --noconfirm $1 $cmd_suffix"
}

install_aurhelper() {
    check_installed "$aurhelper" && nprint "Found '$aurhelper'." && return 0
    
    nprint "Installing '$aurhelper'."
    local src="/home/$username/.local/src/$aurhelper"
    local git_url="https://aur.archlinux.org/$aurhelper.git"

    sudo -u "$username" mkdir -p "/home/$username/.local/src"

    # shellcheck disable=2086
    if ! sudo -u "$username" sh -c "git clone --depth 1 --single-branch --no-tags '$git_url' '$src' $cmd_suffix"; then
        cd "$src" || exit 1
        sudo -u "$username" sh -c "git pull --force origin master $cmd_suffix"
    fi
    cd "$src" || exit 1
    # shellcheck disable=2086
    sudo -u "$username" sh -c "makepkg --noconfirm -si $cmd_suffix"
}

install_essentials() {
    local essential_programs=("base-devel" "git" "rsync")

    sprint "Installing essential programs."
    for p in "${essential_programs[@]}"; do
        if check_installed "$p"; then
            sprint "'$p' is already installed."
        else
            pacman_install "$p" "Installing $p which is required to install and configure other packages."
        fi
    done
}

update_mirrors() {
    reflector --country Germany --latest 16 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
}
