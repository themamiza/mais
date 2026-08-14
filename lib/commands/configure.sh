#!/usr/bin/env bash

command_configure() {
    isRoot || eprint "Only root can configure the system."

    configure_sudo
    configure_grub
    configure_pacman
    configure_makepkg

    if check_installed proxychains; then
        configure_proxychains
    else
        wprint "\`proxychains\` not installed. Install, then run \`mais configure\`."
    fi

    if check_installed keyd; then
        configure_keyd
    else
        wprint "\`keyd\` not installed. Install, then run \`mais configure\`."
    fi
}
