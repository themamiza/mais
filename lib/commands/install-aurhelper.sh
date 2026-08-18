#!/usr/bin/env bash

# shellcheck disable=2154

command_install_aurhelper() {
    isRoot || eprint "Only root can install packages."

    if check_installed "$aurhelper"; then
        nprint "Found '$aurhelper'."
        return 0
    fi

    wheel_can_sudo
    ask_username

    ensure_aur_support || return 0
}
