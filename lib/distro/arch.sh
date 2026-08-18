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

ensure_package() {
    local package="$1"
    local desc="${2:-Required dependency.}"

    check_installed "$package" && return 0
    wprint "'$package' is not installed."

    ! yes_no "Install '$package' now? (Y/N): " && return 1

    sync_packages
    pacman_install "$package" "$desc" || eprint "Failed to install '$package'."
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

aur_ready=false
ensure_aur_support() {
    $aur_ready && return 0

    ensure_package base-devel "Required for building AUR packages." || return 1
    ensure_package git "Required for cloning AUR packages." || return 1

    if ! check_installed "$aurhelper"; then
        sync_packages
        install_aurhelper || eprint "Failed to install '$aurhelper'."
    fi

    aur_ready=true
}

update_mirrors() {
    run_cmd reflector \
        --country Germany \
        --latest 16 \
        --protocol https \
        --sort rate \
        --save /etc/pacman.d/mirrorlist
}
