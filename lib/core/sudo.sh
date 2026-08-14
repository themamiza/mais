#!/usr/bin/env bash

# shellcheck disable=2154

install_sudoers_file() {
    local destination="$1"
    local content="$2"

    run_cmd install -m 0440 /dev/stdin "$destination" <<<"$content"
}

# Remove temporary NOPASSWD access on exit.
trap_cleanup_sudoers() {
    run_cmd rm -f /etc/sudoers.d/mais-tmp
}

wheel_can_sudo() {
    run_cmd rm -f /etc/sudoers.d/mais-tmp

    # Remove temporary sudo access on exit.
    trap trap_cleanup_sudoers HUP INT QUIT TERM PWR EXIT ILL

    # NOPASSWD during setup
    install_sudoers_file /etc/sudoers.d/mais-tmp '%wheel ALL=(ALL) NOPASSWD: ALL'
}

