#!/usr/bin/env bash

# shellcheck disable=2154

# Print the help message listing all available commands and options.
print_help() {
    printf "Usage: %s command [options]

    -- Commands --

        help                    Print this help message and exit

        arch-install
                Install ArchLinux according to the **Installation Guide**
                        <https://wiki.archlinux.org/title/Installation_guide>
                The script will default to UEFI and fallback to BIOS if needed
                The target root filesystem must already be formatted and mounted at '/mnt'.
                Mount additional filesystems such as the EFI system partition
                and home partition under '/mnt' before running this command.

                Designed to run on the live environment.

        install-dotfiles [URL]
                Install dotfiles to your home directory
                If '~/rp/dotfiles' exists, it is used instead of 'URL'

        install-aurhelper aurhelper
                Install an AUR helper for the user
                'aurhelper' should be one of 'yay' or 'paru'
                The script prefers 'yay' and installs it automatically when needed

        install-programs [TAG]
                Install programs from a 'programs.csv' file
                TAG should be one of dwm, hyprland, dev,
                python, clang, lua, bash, js, extra, virt or all.

                With '--tui', all programs are shown in an interactive checklist.
                The selected tag determines which programs are initially checked.

                See 'data/programs.csv' for more information about tags and the file format
                
                
        configure       Do various system configurations (See README.md for details)

        backup [NAME]
                Take a backup from a set of pre-defined files
                NAME is optional and is the name of the directory of the final backup (~/NAME)
                Defaults to '~/backup_\$(date \"+%%Y-%%m-%%d_%%H:%%M\")'

        update-mirrors
                Runs a reflector command to fetch faster mirrors

                Here is what a reflector command looks like:
                \`reflector --country Germany --latest 16 --protocol https --sort rate --save /etc/pacman.d/mirrorlist\`

        install         Install \`%s\` for local usage (Will install to '/usr/local/bin')

    -- Options --

        -v | --verbose          Print as much as possible

        -q | --quiet            Be as quiet as possible

        --tui                   Use the terminal user interface (whiptail)

        **Commands might interactively ask for information, you
                can avoid this by providing them at the command line**

        -u | --username
        -h | --hostname
        -t | --timezone

Written by: drogoniza@gmail.com
" "$program_name" "$program_name"
}
