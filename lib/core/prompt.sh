#!/usr/bin/env bash

# shellcheck disable=2154

yes_no() {
    local answer

    printf "%s" "$1"
    read -r answer || return 1
    [[ "$answer" == [yY] ]]
}

ask_username() {
    local selected_username

    # Return if username is already set.
    [[ -n "$username" ]] && return 0

    while true; do
        ! selected_username="$(ui_input "Username" "Username")" && return 1

        if re_match "$selected_username" "$regex_valid_username"; then
            username="$selected_username"
            return 0
        fi

        ui_message "Invalid username" "Username '$selected_username' is not valid.

Give a username beginning with a letter, with only lowercase letters, - or _." ||
            return 1
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
    local selected_hostname

    # Return if hostname is already set.
    [[ -n "$hostname" ]] && return 0

    while true; do
        ! selected_hostname="$(ui_input "Hostname" "Hostname")" && return 1

        if re_match "$selected_hostname" "$regex_valid_hostname"; then
            hostname="$selected_hostname"
            return 0
        fi

        ui_message "Invalid hostname" "Hostname '$selected_hostname' is not valid.

Give a hostname beginning with a letter, with only lowercase letters, - or _." ||
            return 1
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

confirm_arch_install() {
    local bios_or_uefi="$1"
    local boot_disk="$2"

    printf "\nInstallation configuration:\n
\tUsername:\t%s
\tHostname:\t%s
\tTimezone:\t%s
\tFirmware mode:\t%s\n" "$username" "$hostname" "$timezone" "$bios_or_uefi"

    case "$bios_or_uefi" in
        "UEFI") printf "\tEFI mount:\t/mnt%s\n\tBootloader ID:\t%s\n" "$efi_directory" "$bootloader_id";;
        "BIOS") printf "\tGRUB target disk:\t%s\n" "$boot_disk";;
    esac
    printf "\n"

    printf "The rest of the installation assumes you have\n
1. an internet connection. \`iwctl\`
2. synchronized system clock. \`timedatectl set-ntp true\`
3. configured your filesystem and mounted your root at '/mnt'. \`fdisk\`
4. mounted any additional filesystems below '/mnt'.\n
SHOULD NOT BE RUN ON AN EXISTING ARCH INSTALLATION!\n\n"

    yes_no "Begin installation? (Y/N): "
}
