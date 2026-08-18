#!/usr/bin/env bash

# shellcheck disable=2154

dotfiles_home_root="/home"
dotfiles_v2rayn_binary="/opt/v2rayn-bin/v2rayN"

install_dotfiles() {
    local user_home="$dotfiles_home_root/$username"
    local srcdir="$user_home/rp/dotfiles"
    local rsync_options=(
        -a
        --exclude=/.git/
        --exclude=/.gitignore
        --exclude=/.gitmodules
        --exclude=/LICENSE
        --exclude=/README.md
    )

    sprint "Installing dotfiles."

    # Mainly for my convenience.
    if [ -d "$srcdir" ]; then
        sprint "Found local dotfiles."
    else
        local repo_dir="$user_home/.local/src/$dotfiles_name"

        if isRoot; then
            ensure_package git "Required for cloning dotfiles." || return 1
        else
            check_installed git || eprint "'git' is required to clone the dotfiles repository."
        fi

        sprint "Cloning or updating remote repository."
        sync_git_repo "$username" "$dotfiles_url" "$repo_dir" || return

        srcdir="$repo_dir"
    fi

    run_cmd sudo -u "$username" rsync "${rsync_options[@]}" -- "$srcdir/" "$user_home/" || return

    # Symbolic links to useful applications
    if [[ -f "$dotfiles_v2rayn_binary" ]]; then
        run_cmd sudo -u "$username" ln -sf -- "$dotfiles_v2rayn_binary" "$user_home/.local/bin/v2rayn" || return
    fi

    local wallpapers_link="$user_home/.local/share/wallpapers"

    run_cmd sudo -u "$username" mkdir -p -- "$(dirname "$wallpapers_link")" || return

    if [[ -e "$wallpapers_link" && ! -L "$wallpapers_link" ]]; then
        wprint "'$wallpapers_link' exists and is not a symbolic link."
        return 1
    fi

    run_cmd sudo -u "$username" ln -sfnT -- "$user_home/fl/Pix/Wallpapers" "$wallpapers_link" || return

    return 0
}


command_install_dotfiles() {
    isRoot && wheel_can_sudo
    ask_username
    if isRoot; then
        ensure_package rsync "Required for installing dotfiles." || return 0
    else
        check_installed rsync || eprint "'rsync' is required. Install it first or run this command as root."
    fi
    install_dotfiles
}
