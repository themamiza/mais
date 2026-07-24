#!/usr/bin/env bash

# shellcheck disable=2154

# Return success if running as root.
isRoot() {
    [ "$(id -u)" == 0 ]
}

check_internet_connection() {
    local target="google.com"

    if eval "curl -sSf https://$target -o /dev/null $cmd_suffix"; then
        return 0
    elif eval "ping -c1 -W1 $target $cmd_suffix"; then
        return 0
    else
        return 1
    fi
}
