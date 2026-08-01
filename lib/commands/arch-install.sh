#!/usr/bin/env bash

# shellcheck disable=2154

# Tests replace this path to simulate BIOS and UEFI systems.
arch_efi_platform_size_file="/sys/firmware/efi/fw_platform_size"

generate_fstab() {
    local generated_fstab
    generated_fstab="$(mktemp)"

    if ! genfstab -U /mnt > "$generated_fstab"; then
        rm -f "$generated_fstab"
        eprint "Failed to generate fstab."
    fi

    if [[ ! -s "$generated_fstab" ]]; then
        rm -f "$generated_fstab"
        eprint "Generated fstab is empty."
    fi

    cat "$generated_fstab"
    rm -f "$generated_fstab"
}

# Why do I pass all the variables as arguments? Explained in `arch_install`.
# args: username hostname timezone bios_or_uefi bootloader_id 
# efi_directory boot_disk verbose quiet program_name
arch_install_run_in_chroot() {
    # Renaming vars only for more readability.
    local username="$1"
    local hostname="$2"
    local timezone="$3"
    local bios_or_uefi="$4"
    local bootloader_id="$5"
    local efi_directory="$6"
    local boot_disk="$7"

    # These need to be global so invoked functions can use them.
    verbose="$8"
    quiet="$9"
    program_name="${10}"
    
    # TODO: Should this be done during initial installation?
    # if command -v nvim >/dev/null 2>&1; then
    #     if [ ! -e "/usr/bin/vim" ] || [ -L "/usr/bin/vim" ]; then
    #         sprint "Creating symlink: vim -> nvim."
    #         ln -sf /usr/bin/nvim /usr/bin/vim
    #     fi
    #     if [ ! -e "/usr/bin/vi" ] || [ -L "/usr/bin/vi" ]; then
    #         sprint "Creating symlink: vi -> nvim."
    #         ln -sf /usr/bin/nvim /usr/bin/vi
    #     fi
    # fi
    # printf "\n"

    sprint "Setting timezone to '$timezone'.\n"
    ln -sf "/usr/share/zoneinfo/$timezone" /etc/localtime

    sprint "Configuring hardware clock."
    hwclock --systohc

    sprint "Configuring locale."
    sed -i 's/^#\s*\(en_US.UTF-8\)/\1/' /etc/locale.gen
    run_cmd locale-gen
    printf "LANG=en_US.UTF-8\n" > /etc/locale.conf

    sprint "Setting hostname to '$hostname'."
    printf "%s\n" "$hostname" > /etc/hostname

    # TODO: Check if it's actually necessary to run this command.
    # nprint "Creating new initramfs."
    # run_cmd mkinitcpio -P

    case "$bios_or_uefi" in
        "UEFI")
            sprint "Installing GRUB to '$efi_directory'."
            run_cmd grub-install \
                --target=x86_64-efi --efi-directory="$efi_directory" --bootloader-id="$bootloader_id"
            ;;
        "BIOS")
            sprint "Installing GRUB to '$boot_disk'."
            run_cmd grub-install \
                --target=i386-pc "$boot_disk"
            ;;
    esac

    sprint "Re-creating grub configuration."
    run_cmd grub-mkconfig -o /boot/grub/grub.cfg

    nprint "Creating new user '$username'."
    if ! id "$username" >/dev/null 2>&1; then
        useradd --create-home --user-group --groups wheel --shell /bin/zsh "$username"
    fi

    wheel_can_sudo

    sprint "Enabling NetworkManager."
    run_cmd systemctl enable NetworkManager

    # This should be the last thing done.
    if [ -f "/etc/installation.date" ]; then
        wprint "'/etc/installation.date' already exists."
        yes_no "Do you wish to overwrite it? (Y/N): " && date > /etc/installation.date
    else
        date > /etc/installation.date
    fi
}

arch_install() {
    local boot_disk=""
    local target_efi_directory="/mnt$efi_directory"

    if [[ -r "$arch_efi_platform_size_file" ]]; then
        bios_or_uefi="UEFI"

        mountpoint -q -- "$target_efi_directory" || eprint "UEFI installation requires the EFI system partition mounted at '$target_efi_directory'."
    else
        bios_or_uefi="BIOS"
        ask_boot_disk
    fi

    printf "The rest of the installation assumes you have\n
1. an internet connection. \`iwctl\`
2. synchronized system clock. \`timedatectl set-ntp true\`
3. configured your filesystem and mounted your root at '/mnt'. \`fdisk\`
4. mounted any additional filesystems below '/mnt'.\n\n
SHOULD NOT BE RUN ON AN EXISTING ARCH INSTALLATION!\n\n"
    yes_no "Continue (Y/N): " || exit 0

    ask_username

    # Get password for said user.
    while true; do
        printf "%s's password: " "$username" && read -rs pass1 && printf "\n"
        printf "Retype password: " && read -rs pass2 && printf "\n"
        [ -n "$pass1" ] && [ "$pass1" = "$pass2" ] && unset pass2 && break
        wprint "Passwords do not match or are empty. Try again."
    done

    ask_hostname

    # Change this so it uses fzf for easier access.
    if [ -z "$timezone" ]; then
        while true; do
            printf "Timezone (Region/City) [UTC]: " && read -r timezone
            timezone="${timezone:-UTC}"
            [ -f "/usr/share/zoneinfo/$timezone" ] && break
            wprint "Timezone not valid. A valid timezone looks like -> \"US/Eastern\""
        done
    fi

    # TODO: Print configuration before installing.

    sprint "Checking internet connection...\n"
    check_internet_connection || eprint "Can't reach the web."
    sprint "Internet connection is available.\n"

    base_packages=(base linux-lts linux-firmware grub networkmanager sudo neovim zsh)
    [ "$bios_or_uefi" = "UEFI" ] && base_packages+=(efibootmgr)
    sprint "Bootstrapping the system...\n"
    pacstrap -K /mnt "${base_packages[@]}"
    sprint "Done bootstrapping the system.\n"

    sprint "Generating fstab...\n"
    generate_fstab > /mnt/etc/fstab
    sprint "fstab written to /mnt/etc/fstab.\n"

    # Exporting the function to later be passed to arch-chroot as a command.
    # That is why all the variables are passed manually.
    # TODO: Investigate if it can be done any other way.
    local exported_functions=(arch_install_run_in_chroot run_cmd install_sudoers_file wheel_can_sudo trap_cleanup_sudoers yes_no nprint sprint wprint)
    for fn in "${exported_functions[@]}"; do
        # shellcheck disable=2163
        export -f "$fn"
    done

    # arch_install_run_in_chroot() { # -> args: username hostname timezone bios_or_uefi bootloader_id efi_directory boot_disk verbose quiet program_name
    arch-chroot /mnt /bin/bash -c 'arch_install_run_in_chroot "$@"' _ "$username" "$hostname" "$timezone" "$bios_or_uefi" "$bootloader_id" "$efi_directory" "$boot_disk" "$verbose" "$quiet" "$program_name"

    sprint "Setting password for '$username'."

    if ! printf '%s:%s\n' "$username" "$pass1" | arch-chroot /mnt chpasswd; then
        unset pass1 pass2
        eprint "Failed to set password for '$username'."
    fi
    unset pass1 pass2

    yes_no "The system should be ready to reboot, Continue (Y/N): " || exit 0
    reboot
}

command_arch_install() {
    is_archlinux || eprint "Can only install an ArchLinux system."
    isRoot || eprint "Only root can install the system."

    mountpoint -q /mnt || eprint "\`arch-install\` requires an existing filesystem mounted at '/mnt'."

    arch_install
    exit 0
}
