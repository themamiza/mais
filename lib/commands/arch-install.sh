#!/usr/bin/env bash

# shellcheck disable=2154

# Tests replace this path to simulate BIOS and UEFI systems.
arch_efi_platform_size_file="/sys/firmware/efi/fw_platform_size"

# Why do I pass all the variables as arguments? Explained in `arch_install`.
# args: username pass1 hostname timezone bios_or_uefi bootloader_id 
# efi_directory boot_disk verbose quiet program_name
arch_install_run_in_chroot() {
    # Renaming vars only for more readability.
    local username="$1"
    local pass1="$2"
    local hostname="$3"
    local timezone="$4"
    local bios_or_uefi="$5"
    local bootloader_id="$6"
    local efi_directory="$7"
    local boot_disk="$8"

    # These need to be global so invoked functions can use them.
    verbose="$9"
    quiet="${10}"
    program_name="${11}"
    
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

    sprint "Installing grub bootloader to /efi."
    case "$bios_or_uefi" in
        "UEFI") run_cmd grub-install --target=x86_64-efi --efi-directory="$efi_directory" --bootloader-id="$bootloader_id";;
        "BIOS") run_cmd grub-install --target=i386-pc "$boot_disk";;
    esac

    sprint "Re-creating grub configuration."
    run_cmd grub-mkconfig -o /boot/grub/grub.cfg

    nprint "Creating new user '$username'."
    if ! id "$username" >/dev/null 2>&1; then
        useradd --create-home --user-group --groups wheel --shell /bin/zsh "$username"
    fi

    sprint "Changing password for new user."
    echo "$username:$pass1" | chpasswd
    unset pass1 pass2

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

    printf "The rest of the installation assumes you have\n
1. an internet connection. \`iwctl\`
2. synchronized system clock. \`timedatectl set-ntp true\`
3. configured your filesystem and mounted your root at '/mnt'. \`fdisk\`\n\n
SHOULD NOT BE RAN ON AN EXISTING ARCH INSTALLAION!\n\n"
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
    
    if [[ -r "$arch_efi_platform_size_file" ]]; then
        bios_or_uefi="UEFI"
    else
        bios_or_uefi="BIOS"
        ask_boot_disk
    fi

    sprint "Checking internet connection...\n"
    check_internet_connection || eprint "Can't reach the web."
    sprint "Internet connection is available.\n"

    base_packages=(base linux-lts linux-firmware grub networkmanager sudo neovim zsh)
    [ "$bios_or_uefi" = "UEFI" ] && base_packages+=(efibootmgr)
    sprint "Bootstraping the system...\n"
    pacstrap -K /mnt "${base_packages[@]}"
    sprint "Done bootstrapping the system.\n"

    sprint "Generating fstab...\n"
    genfstab -U /mnt >> /mnt/etc/fstab
    sprint "fstab written to /mnt/etc/fstab.\n"

    # Exporting the function to later be passed to arch-chroot as a command.
    # That is why all the variables are passed manually.
    # TODO: Investigate if it can be done any other way.
    # arch_install_run_in_chroot() { # -> args: username pass1 hostname timezone bios_or_uefi bootloader_id efi_directory boot_disk verbose quiet program_name
    local exported_functions=(arch_install_run_in_chroot run_cmd install_sudoers_file wheel_can_sudo trap_cleanup_sudoers yes_no nprint sprint wprint)
    for fn in "${exported_functions[@]}"; do
        # shellcheck disable=2163
        export -f "$fn"
    done

    arch-chroot /mnt /bin/bash -c 'arch_install_run_in_chroot "$@"' _ "$username" "$pass1" "$hostname" "$timezone" "$bios_or_uefi" "$bootloader_id" "$efi_directory" "$boot_disk" "$verbose" "$quiet" "$program_name"

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
