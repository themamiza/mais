#!/usr/bin/env bash

# shellcheck disable=2154

configure_sudo() {
    sprint "Configuring sudo."

    install_sudoers_file /etc/sudoers.d/00-mais-wheel-can-sudo '%wheel ALL=(ALL:ALL) ALL'

    local nopasswd_commands="/usr/bin/shutdown,/usr/bin/reboot,/usr/bin/systemctl suspend,/usr/bin/mount,/usr/bin/umount,/usr/bin/pacman -Syu,/usr/bin/pacman -Syyu,/usr/bin/pacman -Syyu --noconfirm"

    install_sudoers_file /etc/sudoers.d/01-mais-cmds-without-password "%wheel ALL=(ALL:ALL) NOPASSWD: $nopasswd_commands"

    install_sudoers_file /etc/sudoers.d/02-mais-visudo-editor 'Defaults editor=/usr/bin/nvim'
}
