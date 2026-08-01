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

ask_password() {
    local pass2

    while true; do
        printf "%s's password: " "$username" && read -rs pass1 && printf "\n"
        printf "Retype password: " && read -rs pass2 && printf "\n"

        if [[ -n "$pass1" && "$pass1" == "$pass2" ]]; then
            return 0
        fi

        unset pass1
        wprint "Passwords do not match or are empty. Try again."
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

ask_timezone() {
    local available_timezones
    local selected_timezone

    if [[ -n "$timezone" ]]; then
        if [[ ! -f "/usr/share/zoneinfo/$timezone" ]]; then
            eprint "Timezone '$timezone' is not valid."
        fi

        return 0
    fi

    available_timezones="$(timedatectl list-timezones)" || eprint "Failed to list available timezones."

    if ! selected_timezone="$(printf "%s\n" "$available_timezones" | fzf --height=60% --layout=reverse --border --prompt="Timezone > ")"; then
        eprint "Timezone selection was cancelled."
    fi

    [[ -n "$selected_timezone" ]] || eprint "No timezone was selected."

    timezone="$selected_timezone"
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
