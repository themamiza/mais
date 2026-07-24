#!/usr/bin/env bash

# shellcheck disable=2154

# Download programs.csv when it is not found locally.
ensure_programs_file() {
    local data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/mais"
    local data_file="$data_dir/$programs_filename"

    # Prefer the programs file included in the development repository.
    if [[ -f "$programs_file" ]]; then
        return 0
    fi

    # Fall back to a previously downloaded programs file.
    if [[ -f "$data_file" ]]; then
        programs_file="$data_file"
        return 0
    fi

    nprint "'$programs_filename' not found. Downloading it..."

    mkdir -p "$data_dir"
    programs_file="$data_file"

    if ! eval "curl -fssL '$programs_file_url' -o '$programs_file' $cmd_suffix"; then
        eprint "Failed to download '$programs_filename' from '$programs_file_url'."
    fi
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

install_package() {
    check_installed "$1" && nprint "Found '$1'." && return 0

    # TODO: This grep does not work properly: 'alacritty' matches 'alacritty-theme-git' too.
    local package_info; package_info="$(grep "$1" "$programs_file.clean")"

    while IFS="|" read -r method _ _ description; do
        case "$method" in
            "Pacman"|"") pacman_install    "$1" "$description";;
            "AUR")       aur_install       "$1" "$description";;
            "Suckless")  suckless_install  "$1" "$description";;
            "DoomEmacs") doomemacs_install "$1" "$description";;
        esac
    done <<<"$package_info"
}

# bugged
suckless_install() {
    check_installed "$(basename "$1")" && return 0

    local repo="$1"

    if ! [[ "$repo" =~ ^[^/]+/[^/]+$ ]]; then
        eprint "Invalid suckless repo format: '$repo'. Expected format is 'username/repo'."
    fi

    local src; src="/home/$username/.local/src/$(basename "$repo")"
    local git_url="https://github.com/$repo.git"

    sudo -u "$username" mkdir -p "/home/$username/.local/src"

    # shellcheck disable=2086
    if ! sudo -u "$username" sh -c "git clone --depth 1 --single-branch --no-tags '$git_url' '$src' $cmd_suffix"; then
        cd "$src" || exit 1
        sudo -u "$username" sh -c "git pull --force origin master $cmd_suffix"
    fi
    cd "$src" || exit 1
    # shellcheck disable=2086
    eval "make $cmd_suffix"
    # shellcheck disable=2086
    eval "make install $cmd_suffix"
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
        "X11")      grep -E "X11"                          "$programs_file.clean" | cut -d"|" -f3 >> "$programs_to_install";;
        "DWM")      grep -E "X11|DWM"                      "$programs_file.clean" | cut -d"|" -f3 >> "$programs_to_install";;
        "WAYLAND")  grep -E "WAYLAND"                      "$programs_file.clean" | cut -d"|" -f3 >> "$programs_to_install";;
        "HYPRLAND") grep -E "WAYLAND|HYPRLAND"             "$programs_file.clean" | cut -d"|" -f3 >> "$programs_to_install";;
        "DEV")      grep -E "DEV|PYTHON|CLANG|LUA|BASH|JS" "$programs_file.clean" | cut -d"|" -f3 >> "$programs_to_install";;
        "PYTHON")   grep -E "PYTHON"                       "$programs_file.clean" | cut -d"|" -f3 >> "$programs_to_install";;
        "CLANG")    grep -E "CLANG"                        "$programs_file.clean" | cut -d"|" -f3 >> "$programs_to_install";;
        "LUA")      grep -E "LUA"                          "$programs_file.clean" | cut -d"|" -f3 >> "$programs_to_install";;
        "BASH")     grep -E "BASH"                         "$programs_file.clean" | cut -d"|" -f3 >> "$programs_to_install";;
        "JS")       grep -E "JS"                           "$programs_file.clean" | cut -d"|" -f3 >> "$programs_to_install";;
        "EXTRA")    grep -E "EXTRA"                        "$programs_file.clean" | cut -d"|" -f3 >> "$programs_to_install";;
        "ALL") cut -d"|" -f3 "$programs_file.clean" >> "$programs_to_install";;
    esac

    # Also grab lines that have no tag set.
    awk -F'|' '
      {
        original_line = $0
      }
      NF && $1 !~ /^#/ {
        field2 = $2
        gsub(/^[ \t]+|[ \t]+$/, "", field2)
        if (field2 == "") print original_line
      }
    ' "$programs_file.clean" | cut -d"|" -f3 >> "$programs_to_install"

    # Install nvidia drivers if there's an nvidia gpu
    if lspci | grep -qi nvidia; then
        printf "nvidia-lts\nnvidia-settings\nnvidia-prime\n" >> "$programs_to_install"
    fi

    while IFS= read -r program; do
        install_package "$program"
    done <"$programs_to_install"
}

command_install_programs() {
    isRoot || eprint "Only root can install packages."
    ensure_programs_file
    clean_programs_file
    wheel_can_sudo
    ask_username
    install_essentials
    install_aurhelper
    install_programs "$programs"
}
