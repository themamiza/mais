#!/usr/bin/env bash

# shellcheck disable=2154

yes_no() {
    local answer

    printf "%s" "$1"
    read -r answer || return 1
    [[ "$answer" == [yY] ]]
}

ask_username() {
    local force="${1:-false}"
    local selected_username

    # Return if username is already set and is not forced.
    if [[ -n "$username" && "$force" != true ]]; then
        return 0
    fi

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
    local selected_password
    local pass2

    while true; do
        selected_password=""
        pass2=""

        if ! selected_password="$(ui_password "Password" "$username's password")"; then
            return 1
        fi

        if [[ -z "$selected_password" ]]; then
            ui_message "Invalid password" "Password cannot be empty. Try again." || return 1
            continue
        fi

        if ! pass2="$(ui_password "Confirm password" "Retype password")"; then
            return 1
        fi

        # shellcheck disable=2034
        if [[ "$selected_password" == "$pass2" ]]; then
            pass1="$selected_password"
            return 0
        fi

        ui_message "Passwords do not match" "Passwords do not match. Try again." || return 1
    done
}

ask_hostname() {
    local force="${1:-false}"
    local selected_hostname

    # Return if hostname is already set and is not forced.
    if [[ -n "$hostname" && "$force" != true ]]; then
        return 0
    fi

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
    local force="${1:-false}"
    local available_timezones
    local selected_timezone
    local timezone_entry
    local menu_items=()

    if [[ -n "$timezone" && "$force" != true ]]; then
        if [[ ! -f "/usr/share/zoneinfo/$timezone" ]]; then
            eprint "Timezone '$timezone' is not valid."
        fi

        return 0
    fi

    available_timezones="$(timedatectl list-timezones)" || eprint "Failed to list available timezones."

    while IFS= read -r timezone_entry; do
        [[ -n "$timezone_entry" ]] || continue

        menu_items+=("$timezone_entry" "")
    done <<< "$available_timezones"

    ! selected_timezone="$(ui_menu "Timezone" "Select the system timezone:" "${menu_items[@]}")" && return 1

    [[ -n "$selected_timezone" ]] || return 1

    timezone="$selected_timezone"
}

ask_boot_disk() {
    local selected_boot_disk
    local disk
    local description
    local menu_items=()

    while true; do
        menu_items=()

        while IFS=$'\t' read -r disk description; do
            [[ -n "$disk" ]] || continue
            menu_items+=("$disk" "$description")
        done < <(lsblk -dpno NAME,SIZE,MODEL,TYPE |
                    awk '
                        $NF == "disk" {
                            name = $1
                            size = $2

                            $1 = ""
                            $2 = ""
                            $NF = ""

                            sub(/^[[:space:]]+/, "")
                            sub(/[[:space:]]+$/, "")

                            description = size
                            if (length($0))
                                description = description " " $0

                            print name "\t" description
                        }')

        if (( ${#menu_items[@]} == 0 )); then
            ui_message "No disks found" "No whole disks are available for GRUB installation." || return 1
            return 1
        fi

        if ! selected_boot_disk="$(ui_menu "BIOS boot disk" "Select the whole disk where GRUB will be installed:" "${menu_items[@]}")"; then
            return 1
        fi

        if [[ ! -b "$selected_boot_disk" ]]; then
            ui_message "Invalid boot disk" "'$selected_boot_disk' is not a block device." || return 1
            continue
        fi

        if [[ "$(lsblk -dnro TYPE "$selected_boot_disk" 2>/dev/null)" != "disk" ]]; then
            ui_message "Invalid boot disk" "'$selected_boot_disk' is not a whole disk." || return 1
            continue
        fi

        if ui_yes_no "Confirm boot disk" "Install GRUB to '$selected_boot_disk'?"; then
            boot_disk="$selected_boot_disk"
            return 0
        fi
    done
}

configure_arch_install() {
    local bios_or_uefi="$1"
    local selected
    local menu_items=()

    while true; do
        menu_items=(
            "Username" "Current: $username"
            "Password" "Change account password"
            "Hostname" "Current: $hostname"
            "Timezone" "Current: $timezone"
        )

        if [[ "$bios_or_uefi" == "BIOS" ]]; then
            menu_items+=("Boot disk" "Current: $boot_disk")
        fi

        if ! selected="$(ui_menu "Installation configuration" "Select a setting to edit. Press Cancel when done:" "${menu_items[@]}")"; then
            return 0
        fi

        case "$selected" in
            "Username") ask_username true || continue;;
            "Password") ask_password || continue;;
            "Hostname") ask_hostname true || continue;;
            "Timezone") ask_timezone true || continue;;
            "Boot disk") ask_boot_disk || continue;;
        esac
    done
}

confirm_arch_install() {
    local bios_or_uefi="$1"
    local boot_disk="$2"
    local boot_details
    local message

    case "$bios_or_uefi" in
        UEFI) printf -v boot_details 'EFI mount: /mnt%s\nBootloader ID: %s' "$efi_directory" "$bootloader_id";;
        BIOS) printf -v boot_details 'GRUB target disk: %s' "$boot_disk";;
    esac

    ! $tui && printf "\n"

    # shellcheck disable=2016
    printf -v message \
'Installation configuration:

Username: %s
Hostname: %s
Timezone: %s
Firmware mode: %s
%s

The rest of the installation assumes you have:

1. an internet connection (`iwctl`)
2. synchronized the system clock (`timedatectl set-ntp true`)
3. configured the filesystems and mounted root at `/mnt` (`fdisk`)
4. mounted any additional filesystems below `/mnt`

WARNING: Do not run this on an existing Arch installation.

Begin installation?' \
        "$username" \
        "$hostname" \
        "$timezone" \
        "$bios_or_uefi" \
        "$boot_details"

    ui_yes_no "Confirm installation" "$message"
}
