#!/usr/bin/env bash

configure_pacman() {
    sprint "Configuring \`pacman\` to do Colors, VerbosePkgLists and ILoveCandy."
    sed -i "/^#Color$/s/#//;
            /^#VerbosePkgLists$/s/#//;" /etc/pacman.conf
    grep -q "ILoveCandy" /etc/pacman.conf || sed -i "/^Color$/a ILoveCandy" /etc/pacman.conf
}
