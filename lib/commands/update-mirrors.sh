#!/usr/bin/env bash

# shellcheck disable=2154

command_update_mirrors() {
    is_archlinux || eprint "Not running ArchLinux."
    isRoot || eprint "Only root can update mirrors."
    ensure_package reflector "A Python 3 module and script to retrieve and filter the latest Pacman mirror list." || return 0
    check_internet_connection || eprint "Can't reach the web."
    update_mirrors
}
