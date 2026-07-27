#!/usr/bin/env bash

# shellcheck disable=2154

# Return success if running as root.
isRoot() {
    [ "$(id -u)" == 0 ]
}

run_cmd() {
    if $verbose; then
        "$@"
    else
        "$@" > /dev/null 2>&1
    fi
}

check_internet_connection() {
    local target="google.com"

    if run_cmd curl -sSf "https://$target" -o /dev/null; then
        return 0
    elif run_cmd ping -c1 -W1 "$target"; then
        return 0
    else
        return 1
    fi
}
