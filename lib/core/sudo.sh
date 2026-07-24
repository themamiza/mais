#!/usr/bin/env bash

# shellcheck disable=2154

# This trap runs when the script terminates in any way.
# Removes the tmp sudoers file that let's any user from the wheel group to execute any command.
# Then stores the normal state and exits.
trap_cleanup_sudoers() {
    eval "rm -f /etc/sudoers.d/mais-tmp $cmd_suffix"

    eval "printf '%%wheel ALL=(ALL:ALL) ALL' | install -m 0440 /dev/stdin /etc/sudoers.d/00-mais-wheel-can-sudo $cmd_suffix"

    local nopasswd_commands="/usr/bin/shutdown,/usr/bin/reboot,/usr/bin/systemctl suspend,/usr/bin/mount,/usr/bin/umount,/usr/bin/pacman -Syu,/usr/bin/pacman -Syyu,/usr/bin/pacman -Syyu --noconfirm"

    eval "printf '%%wheel ALL=(ALL:ALL) NOPASSWD: $nopasswd_commands\n' | install -m 0440 /dev/stdin /etc/sudoers.d/01-mais-cmds-without-password $cmd_suffix"

    eval "printf 'Defaults editor=/usr/bin/nvim\n' | install -m 0440 /dev/stdin /etc/sudoers.d/02-mais-visudo-editor $cmd_suffix"
}

wheel_can_sudo() {
    eval "rm -f /etc/sudoers.d/*mais* $cmd_suffix"
    # Remove tmp file and restore normal sudoers functionality on exit.
    trap trap_cleanup_sudoers HUP INT QUIT TERM PWR EXIT ILL
    # NOPASSWD during setup
    eval "printf '%%wheel ALL=(ALL) NOPASSWD: ALL\n' | install -m 0440 /dev/stdin /etc/sudoers.d/mais-tmp $cmd_suffix"
}

