#!/usr/bin/env bash

# shellcheck disable=2154

# Print help message that list all options and flags available.
print_help() {
    printf "Usage: %s command [options]

    -- Commands --

        help                    Print this help message and exit

        arch-install

                Install ArchLinux according to the **Installation Guide** https://wiki.archlinux.org/title/Installation_guide

                The script will default to UEFI and fallback to BIOS if needed

                The target root filesystem must already be formatted and
                mounted at '/mnt'.

                Mount additional filesystems such as the EFI system partition
                and home partition under '/mnt' before running this command.

                Designed to run on the live environment.

        install-dotfiles [dotfiles_url]

                Install dotfiles to your home directory

                'dotfiles_url' is optional and defaults to 'https://github.com/themamiza/dotfiles'

                This command will ignore 'dotfiles_url' altogether if there's a '~/rp/dotfiles' and use that instead

        install-aurhelper aurhelper

                Install aurhelper for the user

                'aurhelper' should be one of 'yay' or 'paru'

                The script prefers 'yay' and will install it on it's own when needed

        install-programs [tag]

                Install programs from a 'programs.csv' file

                'tag' should be one of 'x11', 'dwm', 'wayland', 'hyprland',
                'dev', 'python', 'clang', 'lua', 'bash', 'js', 'extra', 'virt' or 'all'

                Read 'data/programs.csv' for more information about tags and the file itself
                
                
        configure           Do various system configurations (See README.md for details)

        backup [backup_name]

                Take a backup from a set of pre-defined files

                'backup_name' is optional and is the name of the directory of the final backup (~/backup_name)
                Defaults to '~/backup_\$(date \"+%%Y-%%m-%%d_%%H:%%M\")'

        update-mirrors          Runs a reflector command to fetch faster mirrors

                Here is what a reflector command looks like

                \`reflector --country Germany --latest 16 --protocol https --sort rate --save /etc/pacman.d/mirrorlist\`

        install                 Install \`%s\` for local usage
                
                Will install to '/usr/local/bin'

    -- Options --

        -v | --verbose          Print as much as possible

        -q | --quiet            Be as quiet as possible

        --tui                   Use the terminal user interface (whiptail)

        **Commands might interactively ask for information, you can avoid this by providing them at the command line**

        -u | --username
        -h | --hostname
        -t | --timezone

Written by: drogoniza@gmail.com
" "$program_name" "$program_name"
}
