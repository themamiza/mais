#!/usr/bin/env bash

# shellcheck disable=2154

# Download programs.csv when it is not found locally.
ensure_programs_file() {
    if [[ -f "$programs_file" ]]; then
        return 0
    fi

    local user_home
    user_home="$(getent passwd "$username" | cut -d: -f6)" || eprint "Could not determine the home directory for '$username'."
    [[ -n "$user_home" ]] || eprint "Could not determine the home directory for '$username'."

    local data_dir="$user_home/.local/share/mais"
    local data_file="$data_dir/$programs_filename"

    if [[ -f "$data_file" ]]; then
        programs_file="$data_file"
        return 0
    fi

    nprint "'$programs_filename' not found. Downloading it..."

    sudo -H -u "$username" mkdir -p -- "$data_dir" || eprint "Failed to create '$data_dir'."

    if ! sudo -H -u "$username" curl -fssL "$programs_file_url" -o "$data_file"; then 
        rm -f -- "$data_file"
        eprint "Failed to download '$programs_filename' from '$programs_file_url'."
    fi
    programs_file="$data_file"
}

clean_programs_file() { 
    # Remove comments and empty lines
    sed 's/[ ]*#.*//g;/^$/d' "$programs_file" > "$programs_file.clean"

    # Remove all whitespace, but keep quoted strings intact
    gawk -i inplace '
        BEGIN {FS = OFS = "\""}
        /^[[:blank:]]*$/ {next}
        {for (i=1; i<=NF; i+=2) gsub (/[[:space:]]/,"",$i)}
        1
        ' "$programs_file.clean"
}

get_programs_by_tag() {
    local tag_regex="$1"
    local cleaned_file="$2"

    awk -F'|' -v tag_regex="$tag_regex" '$2 ~ tag_regex { print $3 }' "$cleaned_file"
}

install_package() {
    check_installed "$1" && nprint "Found '$1'." && return 0

    local package_info
    package_info="$(awk -F'|' -v package="$1" '$3 == package { print; exit }' "$programs_file.clean")"

    while IFS="|" read -r method _ _ description; do
        case "$method" in
            "Pacman"|"") pacman_install    "$1" "$description";;
            "AUR")       aur_install       "$1" "$description";;
            "Suckless")  suckless_install  "$1" "$description";;
            "DoomEmacs") doomemacs_install "$1" "$description";;
        esac
    done <<<"$package_info"
}

suckless_install() {
    check_installed "$(basename "$1")" && return 0

    local repo="$1"

    if ! [[ "$repo" =~ ^[^/]+/[^/]+$ ]]; then
        eprint "Invalid suckless repo format: '$repo'. Expected format is 'username/repo'."
    fi

    local src; src="/home/$username/.local/src/$(basename "$repo")"
    local git_url="https://github.com/$repo.git"

    sync_git_repo "$username" "$git_url" "$src"

    run_cmd make -C "$src"
    run_cmd make -C "$src" install
}

doomemacs_install() {
    eprint "Not implemented!"
}

install_programs() {
    # Create an empty tmp file.
    : > "$programs_to_install"

    # Grab programs and add to tmp file based on the tag that is provided.
    # case matches the tags to it's children.
    case "$1" in
        "x11")      get_programs_by_tag "^x11$"                       "$programs_file.clean" >> "$programs_to_install";;
        "dwm")      get_programs_by_tag "^(x11|dwm)$"                 "$programs_file.clean" >> "$programs_to_install";;
        "wayland")  get_programs_by_tag "^wayland$"                   "$programs_file.clean" >> "$programs_to_install";;
        "hyprland") get_programs_by_tag "^(wayland|hyprland)$"        "$programs_file.clean" >> "$programs_to_install";;
        "dev")      get_programs_by_tag "^(dev|python|clang|lua|bash|js)$" "$programs_file.clean" >> "$programs_to_install";;
        "python")   get_programs_by_tag "^python$"                    "$programs_file.clean" >> "$programs_to_install";;
        "clang")    get_programs_by_tag "^clang$"                     "$programs_file.clean" >> "$programs_to_install";;
        "lua")      get_programs_by_tag "^lua$"                       "$programs_file.clean" >> "$programs_to_install";;
        "bash")     get_programs_by_tag "^bash$"                      "$programs_file.clean" >> "$programs_to_install";;
        "js")       get_programs_by_tag "^js$"                        "$programs_file.clean" >> "$programs_to_install";;
        "virt")     get_programs_by_tag "^virt$"                      "$programs_file.clean" >> "$programs_to_install";;
        "extra")    get_programs_by_tag "^extra$"                     "$programs_file.clean" >> "$programs_to_install";;
        "all")      cut -d'|' -f3 "$programs_file.clean" >> "$programs_to_install";;
    esac

    # Also grab lines that have no tag set.
    if [[ "$1" != "all" ]]; then
        get_programs_by_tag "^$" "$programs_file.clean" >> "$programs_to_install"
    fi
    # TODO: For a specific tag, untagged programs are still always included.

    # Install nvidia drivers if there's an nvidia gpu
    if lspci | grep -qi nvidia; then
        printf "nvidia-open-lts\nnvidia-settings\nnvidia-prime\n" >> "$programs_to_install"
    fi

    while IFS= read -r program; do
        install_package "$program"
    done <"$programs_to_install"
}

command_install_programs() {
    isRoot || eprint "Only root can install packages."
    ask_username
    ensure_programs_file
    clean_programs_file
    wheel_can_sudo
    install_essentials
    install_aurhelper
    install_programs "$programs"
}
