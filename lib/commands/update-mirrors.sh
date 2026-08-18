#!/usr/bin/env bash

# shellcheck disable=2154

command_update_mirrors() {
    is_archlinux || eprint "Not running ArchLinux."
    isRoot || eprint "Only root can update mirrors."

    check_installed reflector || {
        wprint "\`reflector\` not found."

        if yes_no "Do you want to install it now? (Y/N): "; then
            sync_packages
            pacman_install reflector "A Python 3 module and script to retrieve and filter the latest Pacman mirror list."
        else
            exit 0
        fi
    }

    check_internet_connection || eprint "Can't reach the web."
    update_mirrors
}
