#!/usr/bin/env bash

# shellcheck disable=2034,2154

# Helper function to report incorrect usage.
invalid_option() {
    eprint "Invalid option '$1'
Try '$program_name help' for more information."
}

cli_is_command() {
    case "${1:-}" in
        "help" | \
        "arch-install" | \
        "install-dotfiles" | \
        "install-aurhelper" | \
        "install-programs" | \
        "configure" | \
        "experimental-clean-home" | \
        "backup" | \
        "update-mirrors" | \
        "install")
            return 0
            ;;
    esac

    return 1
}

cli_is_argument_value() {
    local value="${1:-}"

    [[ -n "$value" && "$value" != -* ]] || return 1
    ! cli_is_command "$value"
}

parse_arguments() {
    local command_seen=false
    local selected_command=""

    if [[ $# -lt 1 ]]; then
        print_help
        exit 1
    fi

    while [[ $# -gt 0 ]]; do
        if cli_is_command "$1"; then
            if $command_seen; then
                eprint "Only one command can be provided ('$selected_command' and '$1')."
            fi

            command_seen=true
            selected_command="$1"
        fi

        case "$1" in
            "help")
                help=true
                shift
                ;;

            "arch-install")
                args_arch_install=true
                shift
                ;;

            "install-dotfiles")
                args_install_dotfiles=true

                if cli_is_argument_value "${2:-}"; then
                    dotfiles_url="$2"
                    dotfiles_name="$(basename "$dotfiles_url")"
                    shift 2
                else
                    shift
                fi
                ;;

            "install-aurhelper")
                args_install_aurhelper=true

                if [[ $# -lt 2 ]] || ! cli_is_argument_value "${2:-}"; then
                    eprint "\`install-aurhelper\` -> you should provide an 'aurhelper' (yay, paru)."
                fi

                if ! re_match "$2" "^(yay|paru)$"; then
                    eprint "'$2' is not a valid aurhelper."
                fi

                aurhelper="$2"
                shift 2
                ;;

            "install-programs")
                args_install_programs=true

                if cli_is_argument_value "${2:-}"; then
                    if ! re_match "$2" "^(x11|dwm|wayland|hyprland|dev|python|clang|lua|bash|js|extra|virt|default|all)$"; then
                        eprint "'$2' is not a valid tag."
                    fi

                    programs="$2"
                    shift 2
                else
                    shift
                fi
                ;;

            "configure")
                args_configure=true
                shift
                ;;

            "experimental-clean-home")
                args_clean_home=true
                shift
                ;;

            "backup")
                args_backup=true
                backup_name="backup_$(date "+%Y-%m-%d_%H:%M")"

                if cli_is_argument_value "${2:-}"; then
                    if ! re_match "$2" "$regex_valid_directory"; then
                        eprint "'$2' is not a valid backup name."
                    fi

                    backup_name="$2"
                    shift 2
                else
                    shift
                fi
                ;;

            "update-mirrors")
                args_update_mirrors=true
                shift
                ;;

            "install")
                args_install=true
                shift
                ;;

            "-v"|"--verbose")
                verbose=true
                shift
                ;;

            "-q"|"--quiet")
                quiet=true
                shift
                ;;

            "--tui")
                tui=true
                shift
                ;;

            "-u"|"--username")
                if [[ $# -lt 2 ]] || ! cli_is_argument_value "${2:-}"; then
                    eprint "'$1' -> You should provide a username."
                fi

                username="$2"

                if ! re_match "$username" "$regex_valid_username"; then
                    eprint "Username '$username' is not valid.
Give a username beginning with a letter, with only lowercase letters, - or _."
                fi

                shift 2
                ;;

            "-h"|"--hostname")
                if [[ $# -lt 2 ]] || ! cli_is_argument_value "${2:-}"; then
                    eprint "'$1' -> You should provide a hostname."
                fi

                hostname="$2"

                if ! re_match "$hostname" "$regex_valid_hostname"; then
                    eprint "Hostname '$hostname' is not valid.
Give a hostname beginning with a letter, with only lowercase letters, - or _."
                fi

                shift 2
                ;;

            "-t"|"--timezone")
                if [[ $# -lt 2 ]] || ! cli_is_argument_value "${2:-}"; then
                    eprint "'$1' -> You should provide a timezone."
                fi

                timezone="$2"

                if [[ ! -f "/usr/share/zoneinfo/$timezone" ]]; then
                    eprint "Timezone '$timezone' is not valid.
View valid timezones: \`timedatectl list-timezones\`"
                fi

                shift 2
                ;;

            *)
                invalid_option "$1"
                ;;
        esac
    done

    if $verbose && $quiet; then
        eprint "Can't use '-v' with '-q'."
    fi

    if ! $command_seen; then
        eprint "No command was provided."
    fi

    return 0
}
