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

sync_git_repo() {
    local username="$1"
    local repo_url="$2"
    local destination="$3"

    run_cmd sudo -u "$username" mkdir -p "$(dirname "$destination")"

    if [[ -d "$destination/.git" ]]; then
        run_cmd sudo -u "$username" \
            git -C "$destination" pull --ff-only
        return
    fi

    if [[ -e "$destination" ]]; then
        eprint "'$destination' exists but is not a Git repository."
    fi

    run_cmd sudo -u "$username" \
        git clone \
        --depth 1 \
        --single-branch \
        --no-tags \
        "$repo_url" \
        "$destination"
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
