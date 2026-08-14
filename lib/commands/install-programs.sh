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

    awk -F'|' -v tag_regex="$tag_regex" '
        {
            if ($2 == "") {
                if (tag_regex == "") {
                    print $3
                }

                next
            }

            tag_count = split($2, tags, ",")

            for (i = 1; i <= tag_count; i++) {
                if (tags[i] == tag_regex) {
                    print $3
                    break
                }
            }
        }
    ' "$cleaned_file"
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

install_program_list() {
    while IFS= read -r program; do
        [[ -n "$program" ]] || continue
        install_package "$program"
    done <"$programs_to_install"
}

install_programs() {
    local tag_regex="$1"

    # Create an empty tmp file.
    : > "$programs_to_install"

    # Add programs matching the requested tag to the temporary list.
    if [[ "$1" == "all" ]]; then
        cut -d'|' -f3 "$programs_file.clean" >> "$programs_to_install"
    else
        get_programs_by_tag "$tag_regex" "$programs_file.clean" >> "$programs_to_install"

        # Also include programs with no tag.
        get_programs_by_tag "" "$programs_file.clean" >> "$programs_to_install"
    fi

    # Install NVIDIA drivers when an NVIDIA GPU is detected.
    if lspci | grep -qi nvidia; then
        printf "nvidia-open-lts\nnvidia-settings\nnvidia-prime\n" >> "$programs_to_install"
    fi

    install_program_list
}

select_programs_tui() {
    local checklist_width=100
    local max_package_width=0
    local max_description_width
    local cutoff
    local package
    local description
    local status
    local menu_items=()
    local -A preselected=()

    local selected_tag="${programs:-all}"

    if [[ "$selected_tag" == "all" ]]; then
        while IFS="|" read -r _ _ package _; do
            [[ -n "$package" ]] || continue
            preselected["$package"]=true
        done < "$programs_file.clean"
    else
        while IFS= read -r package; do
            [[ -n "$package" ]] || continue
            preselected["$package"]=true
        done < <(get_programs_by_tag "$selected_tag" "$programs_file.clean")

        # Untagged programs are part of every normal selection.
        while IFS= read -r package; do
            [[ -n "$package" ]] || continue
            preselected["$package"]=true
        done < <(get_programs_by_tag "" "$programs_file.clean")
    fi

    while IFS="|" read -r _ _ package _; do
        [[ -n "$package" ]] || continue

        if (( ${#package} > max_package_width )); then
            max_package_width=${#package}
        fi
    done <"$programs_file.clean"

    # Account for borders, margins, checkbox and spacing between columns.
    max_description_width=$((checklist_width - max_package_width - 14))

    # Avoid excessively short descriptions.
    if (( max_description_width < 20 )); then
        max_description_width=20
    fi

    while IFS="|" read -r _ _ package description; do
        [[ -n "$package" ]] || continue

        description="${description#\"}"
        description="${description%\"}"
        if (( ${#description} > max_description_width )); then
            cutoff=$((max_description_width - 3))
            description="${description:0:cutoff}..."
        fi

        status=off
        [[ -n "${preselected[$package]+set}" ]] && status=on

        menu_items+=("$package" "$description" "$status")
    done <"$programs_file.clean"

    tui_checklist "Program selection" "Select programs to install:" "${menu_items[@]}"
}

command_install_programs() {
    isRoot || eprint "Only root can install packages."

    if $tui && ! command -v whiptail >/dev/null 2>&1; then
        eprint "whiptail is required for --tui. Install the libnewt package first."
    fi

    ask_username
    ensure_programs_file
    clean_programs_file

    if $tui; then
        : >"$programs_to_install"

        if ! select_programs_tui >"$programs_to_install"; then
            : >"$programs_to_install"
            return 0
        fi

        # Confirming an empty checklist is a successful no-op.
        [[ -s "$programs_to_install" ]] || return 0
    fi

    wheel_can_sudo
    install_essentials
    install_aurhelper

    if $tui; then
        install_program_list
    else
        install_programs "${programs:-all}"
    fi
}
