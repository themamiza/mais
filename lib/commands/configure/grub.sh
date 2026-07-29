#!/usr/bin/env bash

# These variables are intentionally not readonly.
# Tests replace them with temporary fixture paths.
grub_defaults_file="/etc/default/grub"
grub_mkinitcpio_file="/etc/mkinitcpio.conf"
grub_output_file="/boot/grub/grub.cfg"
grub_power_state_file="/sys/power/state"
grub_image_size_file="/sys/power/image_size"
grub_meminfo_file="/proc/meminfo"
grub_swaps_file="/proc/swaps"

# Number of bytes in one GiB.
grub_bytes_per_gb=$((1024 * 1024 * 1024))
# Minimum 512 MiB safety margin.
grub_minimum_margin_bytes=$((512 * 1024 * 1024))

bytes_to_gb() {
    local bytes="$1"

    awk -v bytes="$bytes" -v bytes_per_gb="$grub_bytes_per_gb" 'BEGIN { printf "%.6f\n", bytes / bytes_per_gb }'
}

can_hibernate() {
    [[ -r "$grub_power_state_file" ]] || return 1

    grep -qw disk "$grub_power_state_file"
}

hibernation_required_swap_gb() {
    local image_size_bytes
    local margin_bytes

    # Default to the image size that the kernel recommends.
    read -r image_size_bytes < "$grub_image_size_file" || true

    # If not able to read the default value use 2/5 of the RAM size.
    if ! is_number "$image_size_bytes" || (( image_size_bytes == 0 )); then
        local memory_kib

        memory_kib="$(awk '/^MemTotal:/ { print $2; exit }' "$grub_meminfo_file")"

        is_number "$memory_kib" || return 1

        image_size_bytes=$((memory_kib * 1024 * 2 / 5))
    fi

    # Use 1/10 of the image size as margin.
    margin_bytes=$((image_size_bytes / 10))

    # Unless it's less than the minimum, in which case the minimum is used.
    if (( margin_bytes < grub_minimum_margin_bytes )); then
        margin_bytes="$grub_minimum_margin_bytes"
    fi

    bytes_to_gb "$((image_size_bytes + margin_bytes))"
}

grub_block_type() { lsblk -dnro TYPE "$1" 2>/dev/null; }

grub_swap_uuid() { blkid -s UUID -o value "$1" 2>/dev/null; }

largest_active_swap_partition() {
    [[ -r "$grub_swaps_file" ]] || return 1

    local device
    local swap_type
    local size_kib
    local used_kib
    local priority
    local block_type

    local largest_device=""
    local largest_size_kib=0

    # shellcheck disable=2034
    while read -r device swap_type size_kib used_kib priority; do

        [[ "$device" == "Filename" ]] && continue
        ! [[ "$swap_type" == "partition" ]] && continue
        ! is_number "$size_kib" && continue

        block_type="$(grub_block_type "$device" || true)"

        # Only ordinary disk partitions are currently supported.
        # This excludes zram, swap files, LVM and encrypted mappings.
        ! [[ "$block_type" == "part" ]] && continue

        if (( size_kib > largest_size_kib )); then
            largest_device="$device"
            largest_size_kib="$size_kib"
        fi
    done < "$grub_swaps_file"

    [[ -n "$largest_device" ]] || return 1

    local largest_size_bytes
    local largest_size_gb

    largest_size_bytes=$((largest_size_kib * 1024))
    largest_size_gb="$(bytes_to_gb "$largest_size_bytes")"

    printf '%s %s\n' "$largest_device" "$largest_size_gb"
}

mkinitcpio_has_hook() {
    local hook="$1"

    grep -Eq "^HOOKS=.*[=([:space:]]${hook}[)[:space:]]" "$grub_mkinitcpio_file"
}

ensure_mkinitcpio_resume_hook() {
    # A systemd-based initramfs handles resume without the resume hook.
    mkinitcpio_has_hook systemd && return 1
    mkinitcpio_has_hook resume && return 1

    if mkinitcpio_has_hook fsck; then
        sed -Ei '/^HOOKS=/ s/([[:space:](])fsck/\1resume fsck/' "$grub_mkinitcpio_file"
    else
        sed -Ei '/^HOOKS=/ s/[[:space:]]*\)$/ resume)/' "$grub_mkinitcpio_file"
    fi
}

configure_grub() {
    sprint "Configuring grub."

    sed -i "/^GRUB_TIMEOUT=.*$/s/=.*/=3/;
            /^#GRUB_DISABLE_OS_PROBER=false$/s/#//;
            /^GRUB_DEFAULT=.*$/s/=.*/=saved/;
            /^#GRUB_SAVEDEFAULT=true$/s/#//;
            /^GRUB_CMDLINE_LINUX_DEFAULT=.*$/s/ quiet//;" "$grub_defaults_file"

    sprint "Checking hibernation support."

    local required_swap_gb
    local swap_information
    local swap_device
    local swap_size_gb
    local swap_uuid

    if ! can_hibernate; then
        wprint "The kernel does not report hibernation support."
    elif ! required_swap_gb="$(hibernation_required_swap_gb)"; then
        wprint "Could not calculate the required hibernation swap size."
    elif ! swap_information="$(largest_active_swap_partition)"; then
        wprint "Did not find an active plain swap partition."
    else
        read -r swap_device swap_size_gb <<< "$swap_information"

        if ! awk -v available="$swap_size_gb" -v required="$required_swap_gb" 'BEGIN { exit !(available >= required) }'; then
            wprint "Swap partition '$swap_device' provides ${swap_size_gb} GB."
            wprint "Recommended hibernation swap is ${required_swap_gb} GB."
        else
            swap_uuid="$(grub_swap_uuid "$swap_device" || true)"

            if [[ -z "$swap_uuid" ]]; then
                wprint "Could not determine the UUID of '$swap_device'."
            else
                sprint "Enabling hibernation using '$swap_device'."

                if ensure_mkinitcpio_resume_hook; then
                    run_cmd mkinitcpio -P
                fi

                if grep -qE '^GRUB_CMDLINE_LINUX_DEFAULT=.*resume=' "$grub_defaults_file"; then
                    sed -Ei "/^GRUB_CMDLINE_LINUX_DEFAULT=/s#resume=[^ \"']+#resume=UUID=${swap_uuid}#" "$grub_defaults_file"
                else
                    sed -Ei '/^GRUB_CMDLINE_LINUX_DEFAULT=/ { s/"$/ resume=UUID='"$swap_uuid"'"/; }' "$grub_defaults_file"
                fi
            fi
        fi
    fi

    run_cmd grub-mkconfig -o "$grub_output_file"
}
