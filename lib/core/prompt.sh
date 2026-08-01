#!/usr/bin/env bash

# shellcheck disable=2154

yes_no() {
    local answer

    printf "%s" "$1"
    read -r answer || return 1
    [[ "$answer" == [yY] ]]
}

ask_username() {
    # Return if username is already set.
    [ -n "$username" ] && return

    while true; do
        printf "Username: "
        read -r username

        if re_match "$username" "$regex_valid_username"; then
            break
        fi

        wprint "Username '$username' is not valid.\nGive a username beginning with a letter, with only lowercase letters, - or _.\n"
    done
}

ask_hostname() {
    # Return if hostname is already set.
    [ -n "$hostname" ] && return

    while true; do
        printf "Hostname: "
        read -r hostname

        if re_match "$hostname" "$regex_valid_hostname"; then
            break
        fi

        wprint "hostname '$hostname' is not valid.\nGive a hostname beginning with a letter, with only lowercase letters, - or _.\n"
    done
}

ask_boot_disk() {
    while true; do
        printf "\nAvailable disks:\n"
        lsblk -dpno NAME,SIZE,MODEL,TYPE | awk '$NF == "disk"'

        printf "\nBIOS boot disk (for example /dev/sda): "
        read -r boot_disk

        if [[ ! -b "$boot_disk" ]]; then
            wprint "'$boot_disk' is not a block device."
            continue
        fi

        if [[ "$(lsblk -dnro TYPE "$boot_disk" 2>/dev/null)" != "disk" ]]; then
            wprint "'$boot_disk' is not a whole disk."
            continue
        fi

        yes_no "Install GRUB to '$boot_disk'? (Y/N): " && return
    done
}
