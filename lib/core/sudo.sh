#!/usr/bin/env bash

# shellcheck disable=2154

install_sudoers_file() {
    local destination="$1"
    local content="$2"

    run_cmd install -m 0440 /dev/stdin "$destination" <<<"$content"
}

# This trap runs when the script terminates in any way.
# Removes the tmp sudoers file that let's any user from the wheel group to execute any command.
# Then stores the normal state and exits.
trap_cleanup_sudoers() {
    run_cmd rm -f /etc/sudoers.d/mais-tmp

    install_sudoers_file /etc/sudoers.d/00-mais-wheel-can-sudo '%wheel ALL=(ALL:ALL) ALL'

    local nopasswd_commands="/usr/bin/shutdown,/usr/bin/reboot,/usr/bin/systemctl suspend,/usr/bin/mount,/usr/bin/umount,/usr/bin/pacman -Syu,/usr/bin/pacman -Syyu,/usr/bin/pacman -Syyu --noconfirm"

    install_sudoers_file /etc/sudoers.d/01-mais-cmds-without-password "%wheel ALL=(ALL:ALL) NOPASSWD: $nopasswd_commands"

    install_sudoers_file /etc/sudoers.d/02-mais-visudo-editor 'Defaults editor=/usr/bin/nvim'
}

wheel_can_sudo() {
    run_cmd rm -f /etc/sudoers.d/*mais* 

    # Remove tmp file and restore normal sudoers functionality on exit.
    trap trap_cleanup_sudoers HUP INT QUIT TERM PWR EXIT ILL

    # NOPASSWD during setup
    install_sudoers_file /etc/sudoers.d/mais-tmp '%wheel ALL=(ALL) NOPASSWD: ALL'
}

