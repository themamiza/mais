#!/usr/bin/env bash

# shellcheck disable=2154

ensure_mount_point() {
    if mountpoint -q /mnt; then
        wprint "'/mnt' is already in use."
        yes_no "Do you want to unmount before continuing? (Y/N): " && umount -R /mnt && return
        nprint "Proceeding with existing mount points." && return 1
    else
        return 0
    fi
}

# label -> label type: dos/gpt
# size  -> measured in sectors; each sector being 512 bytes.
partition_main() {
    eprint "Not implemented!"
}

partition_x220() {
    case "$bios_or_uefi" in
        "UEFI")
            printf "label: gpt
start=,size=2000000,type=U
start=,size=64000000
start=,size=416000000
start=,size=,type=S\n" | sfdisk /dev/sda --wipe always
        mkfs.fat  -F 32 /dev/sda1
        mkfs.ext4 -qF /dev/sda2
        mkfs.ext4 -qF /dev/sda3
        mkswap /dev/sda4

        mount /dev/sda2 /mnt
        mount --mkdir /dev/sda1 /mnt/efi
        mount --mkdir /dev/sda3 /mnt/home
        swapon /dev/sda4
        ;;

        "BIOS") printf "label: dos
start=,size=64000000
start=,size=\n" | sfdisk /dev/sda --wipe always
        mkfs.ext4 -qF /dev/sda1
        mkfs.ext4 -qF /dev/sda2

        mount /dev/sda1 /mnt
        mount --mkdir /dev/sda2 /mnt/home
        ;;
    esac
}

partition_vm() {
    case "$bios_or_uefi" in
        "UEFI") 
            printf "label: gpt
start=,size=2000000,type=U
start=,size=64000000
start=,size=\n" | sfdisk /dev/vda --wipe always
        mkfs.fat  -F 32 /dev/vda1
        mkfs.ext4 -qF /dev/vda2
        mkfs.ext4 -qF /dev/vda3

        mount /dev/vda2 /mnt
        mount --mkdir /dev/vda1 /mnt/efi
        mount --mkdir /dev/vda3 /mnt/home
        ;;

        "BIOS") printf "label: dos
start=,size=64000000
start=,size=\n" | sfdisk /dev/vda --wipe always
        mkfs.ext4 -qF /dev/vda1
        mkfs.ext4 -qF /dev/vda2

        mount /dev/vda1 /mnt
        mount --mkdir /dev/vda2 /mnt/home
        ;;
    esac
}

# Why do I pass all the variables as arguments? Explained in `arch_install`.
# args: username pass1 hostname timezone bios_or_uefi bootloader_id efi_directory disk_to_install cmd_suffix
# TODO: Fix `arch_install_run_in_chroot` not executing.
arch_install_run_in_chroot() {
    # Renaming vars only for more readability.
    local username="$1"
    local pass1="$2"
    local hostname="$3"
    local timezone="$4"
    local bios_or_uefi="$5"
    local bootloader_id="$6"
    local efi_directory="$7"
    local disk_to_install="$8"
    local cmd_suffix="$9"
    local program_name="${10}"
    
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
    eval "locale-gen $cmd_suffix"
    printf "LANG=en_US.UTF-8\n" > /etc/locale.conf

    sprint "Setting hostname to '$hostname'."
    printf "%s\n" "$hostname" > /etc/hostname

    # TODO: Check if it's actually necessary to run this command.
    # nprint "Creating new initramfs."
    # eval "mkinitcpio -P $cmd_suffix"

    sprint "Installing grub bootloader to /efi."
    case "$bios_or_uefi" in
        "UEFI") eval "grub-install --target=x86_64-efi --efi-directory=$efi_directory --bootloader-id=$bootloader_id $cmd_suffix";;
        "BIOS") eval "grub-install --target=i386-pc $disk_to_install";;
    esac

    sprint "Re-creating grub configuration."
    eval "grub-mkconfig -o /boot/grub/grub.cfg $cmd_suffix"

    nprint "Creating new user '$username'."
    if ! id "$username" >/dev/null 2>&1; then
        useradd --create-home --user-group --groups wheel --shell /bin/bash "$username"
    fi

    sprint "Changing password for new user."
    echo "$username:$pass1" | chpasswd
    unset pass1 pass2

    wheel_can_sudo

    sprint "Enabling NerworkManager."
    eval "systemctl enable NetworkManager $cmd_suffix"

    # This should be the last thing done.
    if [ -f "/etc/installation.date" ]; then
        wprint "'/etc/installation.date' already exists."
        yes_no "Do you wish to overwrite it? (Y/N): " && date > /etc/installation.date
    fi
}

arch_install() {
    printf "The rest of the installation assumes you have
1. an internet connection. \`iwctl\`
2. synchronized system clock. \`timedatectl set-ntp true\`
3. configured your filesystem and mounted your root at '/mnt'. \`fdisk\`\n
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
    
    eval "cat /sys/firmware/efi/fw_platform_size $cmd_suffix" || bios_or_uefi="BIOS"

    sprint "Checking internet connection...\n"
    check_internet_connection || eprint "Can't reach the web."
    sprint "Internet connection is available.\n"

    base_packages=(base linux-lts linux-firmware grub networkmanager sudo neovim)
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
    # arch_install_run_in_chroot() { # -> args: username pass1 hostname timezone bios_or_uefi bootloader_id efi_directory disk_to_install
    local exported_functions=(arch_install_run_in_chroot wheel_can_sudo trap_cleanup_sudoers nprint sprint wprint)
    for fn in "${exported_functions[@]}"; do
        # shellcheck disable=2163
        export -f "$fn"
    done

    arch-chroot /mnt /bin/sh -c "arch_install_run_in_chroot '$username' '$pass1' '$hostname' '$timezone' '$bios_or_uefi' '$bootloader_id' '$efi_directory' '$disk_to_install' '$cmd_suffix' '$program_name'"

    unset pass1 pass2
    yes_no "The system should be ready to reboot, Continue (Y/N): " || exit 0
    reboot
}

command_arch_install() {
    is_archlinux || eprint "Can only install an ArchLinux system."
    isRoot || eprint "Only root can install the system."

    ensure_mount_point &&
        yes_no "Continuing will result in your data being lost. Continue? (Y/N): " && eval "partition_$partition_mode"

    arch_install
    exit
}
