#!/usr/bin/env bash

# shellcheck disable=2154

command_install() {
    is_archlinux || eprint "Not running ArchLinux."
    isRoot || eprint "Only root can install $program_name."
    check_internet_connection || eprint "Can't reach the web."
    
    mkdir -p "$install_path"

    curl "https://raw.githubusercontent.com/themamiza/mais/refs/heads/main/mais" > "$install_path/$program_name"
    chmod 755 "$install_path/$program_name"
}
