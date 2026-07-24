#!/usr/bin/env bash

# shellcheck disable=2154

command_install_aurhelper() {
    isRoot || eprint "Only root can install packages."
    wheel_can_sudo
    ask_username
    install_essentials
    install_aurhelper
}
