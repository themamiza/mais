#!/usr/bin/env bash

# shellcheck disable=2154

resolve_runtime_defaults() {
    # Set username to current user, unless running by root or explicitly specifying the username through arguments.
    ! isRoot && [ -z "$username" ] && username="$(id -un)"

    # If running as root through `sudo`; set username to $SUDO_USER 
    isRoot && [ -n "$SUDO_USER" ] && username="$SUDO_USER"

    # Set hostname to current hostname if not already provided.
    [ -z "$hostname" ] && hostname="$(hostnamectl hostname 2>/dev/null || cat /etc/hostname)"
    [[ "$hostname" == "archiso" ]] && unset hostname

    return 0
}

dispatch_commands() {
    [ -n "$help" ] && print_help && exit 0

    [[ -n "$args_arch_install" ]] && command_arch_install

    [[ -n "$args_install_dotfiles" ]] && command_install_dotfiles

    [[ -n "$args_install_aurhelper" ]] && command_install_aurhelper

    [[ -n "$args_install_programs" ]] && command_install_programs

    [[ -n "$args_configure" ]] && command_configure

    [[ -n "$args_clean_home" ]] && command_experimental_clean_home

    [[ -n "$args_backup" ]] && command_backup

    [[ -n "$args_update_mirrors" ]] && command_update_mirrors

    [[ -n "$args_install" ]] && command_install

    return 0
}
