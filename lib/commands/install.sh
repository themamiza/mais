#!/usr/bin/env bash

# shellcheck disable=2154

command_install() {
    is_archlinux || eprint "Not running ArchLinux."
    isRoot || eprint "Only root can install $program_name."
    check_internet_connection || eprint "Can't reach the web."

    local release_url="https://github.com/themamiza/mais/releases/latest/download"
    local destination="$install_path/mais"
    local temporary_directory

    temporary_directory="$(mktemp -d)" || eprint "Could not create a temporary directory."

    if ! run_cmd curl --fail --location --silent --show-error "$release_url/mais" --output "$temporary_directory/mais"; then
        rm -rf "$temporary_directory"
        eprint "Could not download the latest mais release."
    fi

    if ! run_cmd curl --fail --location --silent --show-error "$release_url/mais.sha256" --output "$temporary_directory/mais.sha256"; then
        rm -rf "$temporary_directory"
        eprint "Could not download the release checksum."
    fi

    if ! (cd "$temporary_directory" && sha256sum --check --status mais.sha256); then
        rm -rf "$temporary_directory"
        eprint "Release checksum verification failed."
    fi

    if ! run_cmd install -Dm755 -- "$temporary_directory/mais" "$destination"; then
        rm -rf "$temporary_directory"
        eprint "Could not install mais."
    fi

    rm -rf "$temporary_directory"

    sprint "Installed the latest mais release to '$destination'."
}
