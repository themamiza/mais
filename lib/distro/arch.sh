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

packages_synced=false

sync_packages() {
    $packages_synced && return 0

    nprint "Synchronizing package databases and keyring."
    run_cmd pacman -Sy --needed --noconfirm archlinux-keyring || eprint "Failed to synchronize package databases and keyring."

    nprint "Upgrading installed packages."
    run_cmd pacman -Su --noconfirm || eprint "Failed to upgrade the system."

    packages_synced=true
}

pacman_install() {
    nprint "Installing $1 -> $2"
    run_cmd pacman -S --noconfirm "$1"
}

aur_install() {
    nprint "Installing $1 -> $2"
    run_cmd sudo -u "$username" "$aurhelper" -S --noconfirm "$1"
}

install_aurhelper() {
    check_installed "$aurhelper" && nprint "Found '$aurhelper'." && return 0

    nprint "Installing '$aurhelper'."

    local src="/home/$username/.local/src/$aurhelper"
    local git_url="https://aur.archlinux.org/$aurhelper.git"

    sync_git_repo "$username" "$git_url" "$src"

    # Run the makepkg in it's own subshell, don't want the main CWD to change.
    (
        cd "$src" || exit 1
        run_cmd sudo -u "$username" makepkg --noconfirm -si
    )
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
    run_cmd reflector \
        --country Germany \
        --latest 16 \
        --protocol https \
        --sort rate \
        --save /etc/pacman.d/mirrorlist
}
