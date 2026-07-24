#!/usr/bin/env bash

# shellcheck disable=2154

sync_file() {
    local src="$1"
    local dest="$2"

    if [ -d "$src" ]; then
        rsync -aPR "$src" "$dest/"
    elif [ -f "$src" ]; then
        local dest_dir; dest_dir="$dest/$(dirname "$src")"
        mkdir -p "$dest_dir"
        rsync -aP "$src" "$dest_dir/"
    else
        wprint "$src not found."
    fi
}

perform_backup() {
    local backup_dest="$HOME/$backup_name"
    local backup_files=(
        "$PASSWORD_STORE_DIR"

        "${XDG_DATA_HOME:-$HOME/.local/share}/vpn_credentials"

        "${XDG_DATA_HOME:-$HOME/.local/share}/wallpapers"

        "$HOME/.minecraft/saves"
        "$HOME/.minecraft/mods"
        "$HOME/.minecraft/shaderpacks"
        "$HOME/.minecraft/resourcepacks"
        "$HOME/.minecraft/config"
        "$HOME/.minecraft/schematics"
        "$HOME/.minecraft/screenshots"
        "$HOME/.minecraft/options.txt"

        "$HOME/.cache/zsh"

        "$HOME/dl"
        "$HOME/pix"
        "$HOME/rp"
    )

    mkdir -p "$backup_dest"

    for file in "${backup_files[@]}"; do
        sync_file "$file" "$backup_dest"
    done

    # TODO: consider compressing the backup.
    # 7z a -t7z -mx=9 "backup-$(date "+%Y-%m-%d")" "$backup_dest"

    # Warn about what is not being backed up
    wprint "== Backup anything browser related (extension settings, downloads, bookmarks, sync, ...) manually!"
}

command_backup() {
    isRoot && eprint "Root cannot take backups."
    perform_backup
}

