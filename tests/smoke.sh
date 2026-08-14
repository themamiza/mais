#!/usr/bin/env bash

# shellcheck disable=2016,2034,2154

set -uo pipefail

TEST_ROOT="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." \
        >/dev/null 2>&1 &&
        pwd -P
)" || exit 1
readonly TEST_ROOT

MAIS="${1:-$TEST_ROOT/mais}"
readonly MAIS

[[ -f "$MAIS" ]] || {
    printf 'Script under test not found: %s\n' "$MAIS" >&2
    exit 1
}

TEST_TMP="$(mktemp -d)" || exit 1
readonly TEST_TMP

failed=0
total=0

cleanup() {
    rm -rf "$TEST_TMP"
}

trap cleanup EXIT

run_test() {
    local name="$1"
    local expected_status="$2"
    local expected_stream="$3"
    local expected_text="$4"
    shift 4

    local stdout_file="$TEST_TMP/$name.stdout"
    local stderr_file="$TEST_TMP/$name.stderr"
    local search_file
    local actual_status

    ((total++))

    "$@" >"$stdout_file" 2>"$stderr_file"
    actual_status=$?

    case "$expected_stream" in
        stdout) search_file="$stdout_file" ;;
        stderr) search_file="$stderr_file" ;;
        *)
            printf 'FAIL: %s has an invalid expected stream\n' "$name"
            ((failed++))
            return
            ;;
    esac

    if (( actual_status != expected_status )); then
        printf 'FAIL: %s\n' "$name"
        printf '  expected status: %d\n' "$expected_status"
        printf '  actual status:   %d\n' "$actual_status"
        ((failed++))
        return
    fi

    if ! grep -Fq -- "$expected_text" "$search_file"; then
        printf 'FAIL: %s\n' "$name"
        printf '  expected %s to contain: %s\n' \
            "$expected_stream" \
            "$expected_text"

        printf '  stdout:\n'
        sed 's/^/    /' "$stdout_file"

        printf '  stderr:\n'
        sed 's/^/    /' "$stderr_file"

        ((failed++))
    fi
}

run_parser() {
    bash -c '
        set -e

        MAIS_ROOT="$1"
        shift

        source "$MAIS_ROOT/lib/core/config.sh"
        source "$MAIS_ROOT/lib/core/log.sh"
        source "$MAIS_ROOT/lib/core/validate.sh"
        source "$MAIS_ROOT/lib/cli/help.sh"
        source "$MAIS_ROOT/lib/cli/parser.sh"

        parse_arguments "$@"

        printf "programs=<%s> verbose=<%s> tui=<%s>\n" \
            "${programs:-}" \
            "$verbose" \
            "$tui"
    ' _ "$TEST_ROOT" "$@"
}

run_core_command_checks() {
    bash -c '
        source "$1/lib/core/run.sh"

        verbose=false

        hidden="$(
            run_cmd bash -c \
                "printf visible; printf error >&2"
        )"

        run_cmd bash -c "exit 7"
        status=$?

        verbose=true
        shown="$(run_cmd printf visible)"

        printf "hidden=<%s> shown=<%s> status=<%s>\n" \
            "$hidden" \
            "$shown" \
            "$status"
    ' _ "$TEST_ROOT"
}

run_git_sync() {
    local scenario="$1"

    bash -c '
        source "$1/lib/core/run.sh"

        test_dir="$2/git-$3"
        scenario="$3"

        rm -rf "$test_dir"
        mkdir -p "$test_dir"

        calls=()

        run_cmd() {
            case " $* " in
                *" git clone "*)
                    calls+=(clone)
                    ;;
                *" git -C "*" pull --ff-only "*)
                    calls+=(pull)
                    ;;
                *" mkdir -p "*)
                    calls+=(mkdir)
                    ;;
            esac
        }

        eprint() {
            printf "%s\n" "$1" >&2
            exit 1
        }

        if [[ "$scenario" == normal ]]; then
            mkdir -p "$test_dir/existing/.git"

            sync_git_repo \
                testuser \
                https://example.com/missing.git \
                "$test_dir/missing"

            sync_git_repo \
                testuser \
                https://example.com/existing.git \
                "$test_dir/existing"

            printf "calls=<%s>\n" "${calls[*]}"
        else
            mkdir -p "$test_dir/not-git"

            sync_git_repo \
                testuser \
                https://example.com/not-git.git \
                "$test_dir/not-git"
        fi
    ' _ "$TEST_ROOT" "$TEST_TMP" "$scenario"
}

run_program_selection() {
    bash -c '
        source "$1/lib/commands/install-programs.sh"

        programs_file="$2/programs.csv"
        programs_to_install="$2/programs.tmp"

        cat >"$programs_file.clean" <<EOF
|hyprland,desktop|wl-clipboard|"Wayland clipboard"
|hyprland|hyprland|"Wayland compositor"
||base-package|"Always installed"
|notwayland|wrong-package|"Must not partially match"
EOF

        lspci() {
            return 1
        }

        selected=()

        install_package() {
            selected+=("$1")
        }

        install_programs hyprland

        printf "selected=<%s>\n" "${selected[*]}"
    ' _ "$TEST_ROOT" "$TEST_TMP"
}

run_package_lookup() {
    bash -c '
        source "$1/lib/commands/install-programs.sh"

        programs_file="$2/programs.csv"

        cat >"$programs_file.clean" <<EOF
|extra|alacritty|"Terminal"
AUR|extra|alacritty-theme-git|"Themes"
EOF

        check_installed() {
            return 1
        }

        pacman_install() {
            printf "method=<pacman:%s>\n" "$1"
        }

        aur_install() {
            printf "method=<aur:%s>\n" "$1"
        }

        install_package alacritty
    ' _ "$TEST_ROOT" "$TEST_TMP"
}

run_sudoers_install() {
    bash -c '
        source "$1/lib/core/sudo.sh"

        run_cmd() {
            local input

            IFS= read -r input

            printf "record=<%s|%s>\n" \
                "$*" \
                "$input"
        }

        install_sudoers_file \
            /tmp/mais-sudoers \
            "%wheel ALL=(ALL) NOPASSWD: ALL"
    ' _ "$TEST_ROOT"
}

run_install_release() {
    local scenario="$1"

    bash -c '
        source "$1/lib/commands/install.sh"

        scenario="$2"
        test_dir="$3/install-$scenario"
        install_path="$test_dir/bin"
        destination="$install_path/mais"
        program_name=mais

        rm -rf "$test_dir"
        mkdir -p "$install_path"
        printf "old-release\n" >"$destination"

        calls=()
        installed=no

        is_archlinux() {
            return 0
        }

        isRoot() {
            return 0
        }

        check_internet_connection() {
            return 0
        }

        sprint() {
            :
        }

        mktemp() {
            rm -rf "$test_dir/download"
            mkdir -p "$test_dir/download"
            printf "%s\n" "$test_dir/download"
        }

        eprint() {
            printf "error=<%s> calls=<%s> installed=<%s> content=<%s>\n" "$1" "${calls[*]}" "$installed" "$(cat "$destination")" >&2
            exit 1
        }

        run_cmd() {
            local command="$1"
            shift

            case "$command" in
                curl)
                    local url=
                    local output=

                    while (( $# )); do
                        case "$1" in
                            https://*)
                                url="$1"
                                shift
                                ;;
                            --output)
                                output="$2"
                                shift 2
                                ;;
                            *)
                                shift
                                ;;
                        esac
                    done

                    local asset="${url##*/}"
                    calls+=("curl:$asset")

                    [[ "$scenario" == download-failure && "$asset" == mais ]] && return 7

                    if [[ "$asset" == mais ]]; then
                        printf "new-release\n" >"$output"
                    elif [[ "$scenario" == checksum-failure ]]; then
                        printf "%064d  mais\n" 0 >"$output"
                    else
                        (cd "${output%/*}" && sha256sum mais >"${output##*/}")
                    fi
                    ;;
                install)
                    local destination_argument="${!#}"
                    local source_index=$(( $# - 1 ))
                    local source_argument="${!source_index}"

                    calls+=(install)

                    [[ " $* " == *" -Dm755 "* ]] || return 9
                    [[ "$destination_argument" == "$destination" ]] || return 9

                    command cp "$source_argument" "$destination_argument"
                    command chmod 755 "$destination_argument"
                    installed=yes
                    ;;
                *)
                    return 10
                    ;;
            esac
        }

        command_install

        printf "calls=<%s> installed=<%s> content=<%s>\n" "${calls[*]}" "$installed" "$(cat "$destination")"
    ' _ "$TEST_ROOT" "$scenario" "$TEST_TMP"
}

run_arch_install_command() {
    local root_mounted="${1:-true}"

    bash -c '
        source "$1/lib/commands/arch-install.sh"

        root_mounted="$2"

        is_archlinux() {
            return 0
        }

        isRoot() {
            return 0
        }

        mountpoint() {
            [[ "$root_mounted" == true ]]
        }

        arch_install() {
            printf "install=<yes>\n"
        }

        eprint() {
            printf "%s\n" "$1" >&2
            exit 1
        }

        command_arch_install
    ' _ "$TEST_ROOT" "$root_mounted"
}

run_arch_install_bootstrap() {
    local scenario="$1"

    bash -c '
        set -e

        source "$1/lib/commands/arch-install.sh"

        scenario="$2"
        test_dir="$3/arch-bootstrap-$scenario"

        rm -rf "$test_dir"
        mkdir -p "$test_dir"

        username=testuser
        hostname=testhost
        timezone=UTC
        bootloader_id=GRUB
        efi_directory=/efi

        ask_boot_disk() {
            boot_disk=/dev/test-disk
        }

        verbose=false
        quiet=false
        tui=false
        program_name=mais

        arch_efi_platform_size_file="$test_dir/fw-platform-size"

        install_live_deps() {
            :
        }

        if [[ "$scenario" == uefi ]]; then
            touch "$arch_efi_platform_size_file"
        fi

        mountpoint() {
            return 0
        }

        yes_no() {
            return 0
        }

        ask_username() {
            :
        }

        ask_password() {
            pass1=test-password
        }

        ask_hostname() {
            :
        }

        ask_timezone() {
            :
        }

        check_internet_connection() {
            return 0
        }

        sprint() {
            :
        }

        nprint() {
            :
        }

        wprint() {
            :
        }

        confirm_arch_install() {
            return 0
        }

        pacstrap() {
            shift 2

            if [[ "$scenario" == failure ]]; then
                printf "pacstrap=<failed>\n"
                return 7
            fi

            local package
            local packages=" $* "
            local required=yes
            local efibootmgr=no

            for package in \
                base \
                linux-lts \
                linux-firmware \
                grub \
                networkmanager \
                sudo \
                neovim
            do
                [[ "$packages" == *" $package "* ]] ||
                    required=no
            done

            [[ "$packages" == *" efibootmgr "* ]] &&
                efibootmgr=yes

            printf "required=<%s> efibootmgr=<%s>\n" \
                "$required" \
                "$efibootmgr"

            exit 0
        }

        arch_install
    ' _ "$TEST_ROOT" "$scenario" "$TEST_TMP"
}

run_grub_helpers() {
    bash -c '
        source "$1/lib/core/validate.sh"
        source "$1/lib/commands/configure/grub.sh"

        test_dir="$2/grub-helpers"

        rm -rf "$test_dir"
        mkdir -p "$test_dir"

        grub_power_state_file="$test_dir/power-state"
        grub_image_size_file="$test_dir/image-size"
        grub_meminfo_file="$test_dir/meminfo"
        grub_swaps_file="$test_dir/swaps"

        printf "freeze mem disk\n" \
            >"$grub_power_state_file"

        printf "%d\n" \
            "$((4 * 1024 * 1024 * 1024))" \
            >"$grub_image_size_file"

        printf "MemTotal: 16777216 kB\n" \
            >"$grub_meminfo_file"

        cat >"$grub_swaps_file" <<EOF
Filename Type Size Used Priority
/dev/zram0 partition 8388608 0 100
/swapfile file 16777216 0 -2
/dev/sda2 partition 4194304 0 -2
/dev/nvme0n1p3 partition 6291456 0 -3
EOF

        grub_block_type() {
            if [[ "$1" == /dev/zram0 ]]; then
                printf "disk\n"
            else
                printf "part\n"
            fi
        }

        printf "required=<%s> swap=<%s>\n" \
            "$(hibernation_required_swap_gb)" \
            "$(largest_active_swap_partition)"
    ' _ "$TEST_ROOT" "$TEST_TMP"
}

run_grub_configuration() {
    local scenario="$1"

    bash -c '
        source "$1/lib/core/validate.sh"
        source "$1/lib/commands/configure/grub.sh"

        test_dir="$2/grub-$3"
        scenario="$3"

        rm -rf "$test_dir"
        mkdir -p "$test_dir"

        grub_defaults_file="$test_dir/default-grub"
        grub_mkinitcpio_file="$test_dir/mkinitcpio.conf"
        grub_output_file="$test_dir/grub.cfg"
        grub_power_state_file="$test_dir/power-state"
        grub_image_size_file="$test_dir/image-size"
        grub_meminfo_file="$test_dir/meminfo"
        grub_swaps_file="$test_dir/swaps"

        case "$scenario" in
            new)
                printf "%s\n" \
                    "GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet\"" \
                    >"$grub_defaults_file"

                printf "HOOKS=(base udev autodetect fsck)\n" \
                    >"$grub_mkinitcpio_file"
                ;;
            existing)
                printf "%s\n" \
                    "GRUB_CMDLINE_LINUX_DEFAULT=\"resume=UUID=old loglevel=3\"" \
                    >"$grub_defaults_file"

                printf "HOOKS=(base udev autodetect resume fsck)\n" \
                    >"$grub_mkinitcpio_file"
                ;;
            no-swap)
                printf "%s\n" \
                    "GRUB_CMDLINE_LINUX_DEFAULT=\"quiet\"" \
                    >"$grub_defaults_file"

                printf "HOOKS=(base udev autodetect fsck)\n" \
                    >"$grub_mkinitcpio_file"
                ;;
        esac

        printf "freeze mem disk\n" \
            >"$grub_power_state_file"

        printf "%d\n" \
            "$((4 * 1024 * 1024 * 1024))" \
            >"$grub_image_size_file"

        printf "MemTotal: 16777216 kB\n" \
            >"$grub_meminfo_file"

        if [[ "$scenario" == no-swap ]]; then
            printf "Filename Type Size Used Priority\n" \
                >"$grub_swaps_file"
        else
            printf \
                "Filename Type Size Used Priority\n/dev/sda2 partition 6291456 0 -2\n" \
                >"$grub_swaps_file"
        fi

        grub_block_type() {
            printf "part\n"
        }

        grub_swap_uuid() {
            printf "test-swap-uuid\n"
        }

        sprint() {
            :
        }

        wprint() {
            :
        }

        calls=()

        run_cmd() {
            [[ "$1" == mkinitcpio ]] &&
                calls+=(initramfs)

            [[ "$1" == grub-mkconfig ]] &&
                calls+=(grub)

            return 0
        }

        configure_grub

        grub_line="$(
            grep \
                "^GRUB_CMDLINE_LINUX_DEFAULT=" \
                "$grub_defaults_file"
        )"

        resume="$(
            grep -o \
                "resume=UUID=[^ \" ]*" \
                <<<"$grub_line" ||
                true
        )"

        resume_count="$(
            grep -o "resume=" <<<"$grub_line" |
                wc -l |
                tr -d " "
        )"

        if grep -qw resume "$grub_mkinitcpio_file"; then
            hook=yes
        else
            hook=no
        fi

        if [[ " ${calls[*]} " == *" initramfs "* ]]; then
            initramfs=yes
        else
            initramfs=no
        fi

        if [[ " ${calls[*]} " == *" grub "* ]]; then
            grub=yes
        else
            grub=no
        fi

        printf \
            "resume=<%s> count=<%s> hook=<%s> initramfs=<%s> grub=<%s>\n" \
            "${resume:-none}" \
            "$resume_count" \
            "$hook" \
            "$initramfs" \
            "$grub"
    ' _ "$TEST_ROOT" "$TEST_TMP" "$scenario"
}

run_dotfiles_install() {
    local scenario="$1"

    bash -c '
        source "$1/lib/commands/install-dotfiles.sh"

        test_dir="$2/dotfiles-$3"
        scenario="$3"

        rm -rf "$test_dir"
        mkdir -p "$test_dir"

        username=testuser
        dotfiles_url=https://example.com/dotfiles.git
        dotfiles_name=dotfiles
        dotfiles_home_root="$test_dir/home"
        dotfiles_v2rayn_binary="$test_dir/v2rayN"

        user_home="$dotfiles_home_root/$username"
        wallpapers_link="$user_home/.local/share/wallpapers"

        mkdir -p \
            "$user_home" \
            "$user_home/fl/Pix/Wallpapers"

        calls=()
        excludes=yes

        sprint() {
            :
        }

        wprint() {
            printf "%s\n" "$1" >&2
        }

        sync_git_repo() {
            calls+=(sync)

            [[ "$scenario" == sync-failure ]] &&
                return 7

            return 0
        }

        run_cmd() {
            local action=other
            local argument
            local destination="${!#}"
            local option

            for argument in "$@"; do
                [[ "$argument" == rsync ]] &&
                    action=rsync

                [[ "$argument" == mkdir ]] &&
                    action=wallpapers-parent

                if [[ "$argument" == ln ]]; then
                    if [[ "$destination" == "$wallpapers_link" ]]; then
                        action=wallpapers-link
                    else
                        action=v2rayn-link
                    fi
                fi
            done

            if [[ "$action" == rsync ]]; then
                for option in \
                    --exclude=/.git/ \
                    --exclude=/.gitignore \
                    --exclude=/.gitmodules \
                    --exclude=/LICENSE \
                    --exclude=/README.md
                do
                    [[ " $* " == *" $option "* ]] ||
                        excludes=no
                done
            fi

            calls+=("$action")

            if [[ "$scenario" == rsync-failure &&
                "$action" == rsync ]]; then
                return 8
            fi

            if [[ "$scenario" == link-failure &&
                "$action" == wallpapers-link ]]; then
                return 9
            fi

            return 0
        }

        [[ "$scenario" == conflict ]] &&
            mkdir -p "$wallpapers_link"

        install_dotfiles
        status=$?

        printf "calls=<%s> excludes=<%s>\n" \
            "${calls[*]}" \
            "$excludes"

        exit "$status"
    ' _ "$TEST_ROOT" "$TEST_TMP" "$scenario"
}

run_test \
    "help" \
    0 \
    stdout \
    "Usage:" \
    "$MAIS" help

run_test \
    "no-arguments" \
    1 \
    stdout \
    "Usage:" \
    "$MAIS"

run_test \
    "invalid-command" \
    1 \
    stderr \
    "Invalid option" \
    "$MAIS" not-a-command

run_test \
    "outside-repository" \
    0 \
    stdout \
    "Usage:" \
    bash -c 'cd /tmp && "$1" help' _ "$MAIS"

run_test \
    "conflicting-output-options" \
    1 \
    stderr \
    "Can't use '-v' with '-q'." \
    "$MAIS" help --verbose --quiet

run_test \
    "valid-program-tag" \
    0 \
    stdout \
    "programs=<dev> verbose=<false>" \
    run_parser install-programs dev

run_test \
    "uppercase-program-tag" \
    1 \
    stderr \
    "'DEV' is not a valid tag" \
    "$MAIS" install-programs DEV

run_test \
    "missing-required-argument" \
    1 \
    stderr \
    "should provide an 'aurhelper'" \
    "$MAIS" install-aurhelper

run_test \
    "multiple-commands" \
    1 \
    stderr \
    "Only one command can be provided" \
    "$MAIS" help configure

run_test \
    "run-command-behavior" \
    0 \
    stdout \
    "hidden=<> shown=<visible> status=<7>" \
    run_core_command_checks

run_test \
    "git-sync-clones-and-updates" \
    0 \
    stdout \
    "calls=<mkdir clone mkdir pull>" \
    run_git_sync normal

run_test \
    "git-sync-rejects-non-git-directory" \
    1 \
    stderr \
    "exists but is not a Git repository" \
    run_git_sync non-git

run_test \
    "hyprland-program-selection" \
    0 \
    stdout \
    "selected=<wl-clipboard hyprland base-package>" \
    run_program_selection

run_test \
    "exact-package-lookup" \
    0 \
    stdout \
    "method=<pacman:alacritty>" \
    run_package_lookup

run_test \
    "sudoers-file-permissions" \
    0 \
    stdout \
    "record=<install -m 0440 /dev/stdin /tmp/mais-sudoers|%wheel ALL=(ALL) NOPASSWD: ALL>" \
    run_sudoers_install

run_test \
    "install-downloads-verifies-and-installs" \
    0 \
    stdout \
    "calls=<curl:mais curl:mais.sha256 install> installed=<yes> content=<new-release>" \
    run_install_release success

run_test \
    "install-stops-on-download-failure" \
    1 \
    stderr \
    "error=<Could not download the latest mais release.> calls=<curl:mais> installed=<no> content=<old-release>" \
    run_install_release download-failure

run_test \
    "install-stops-on-checksum-failure" \
    1 \
    stderr \
    "error=<Release checksum verification failed.> calls=<curl:mais curl:mais.sha256> installed=<no> content=<old-release>" \
    run_install_release checksum-failure

run_test \
    "arch-install-starts-with-prepared-filesystem" \
    0 \
    stdout \
    "install=<yes>" \
    run_arch_install_command true

run_test \
    "arch-install-requires-mounted-root" \
    1 \
    stderr \
    "requires an existing filesystem mounted at '/mnt'" \
    run_arch_install_command false

run_test \
    "arch-install-bootstraps-required-packages" \
    0 \
    stdout \
    "required=<yes> efibootmgr=<no>" \
    run_arch_install_bootstrap bios

run_test \
    "arch-install-uefi-includes-efibootmgr" \
    0 \
    stdout \
    "required=<yes> efibootmgr=<yes>" \
    run_arch_install_bootstrap uefi

run_test \
    "arch-install-propagates-pacstrap-failure" \
    7 \
    stdout \
    "pacstrap=<failed>" \
    run_arch_install_bootstrap failure

run_test \
    "grub-hibernation-calculation" \
    0 \
    stdout \
    "required=<4.500000> swap=</dev/nvme0n1p3 6.000000>" \
    run_grub_helpers

run_test \
    "grub-enables-hibernation" \
    0 \
    stdout \
    "resume=<resume=UUID=test-swap-uuid> count=<1> hook=<yes> initramfs=<yes> grub=<yes>" \
    run_grub_configuration new

run_test \
    "grub-replaces-existing-resume" \
    0 \
    stdout \
    "resume=<resume=UUID=test-swap-uuid> count=<1> hook=<yes> initramfs=<no> grub=<yes>" \
    run_grub_configuration existing

run_test \
    "grub-regenerates-without-swap" \
    0 \
    stdout \
    "resume=<none> count=<0> hook=<no> initramfs=<no> grub=<yes>" \
    run_grub_configuration no-swap

run_test \
    "dotfiles-install" \
    0 \
    stdout \
    "calls=<sync rsync wallpapers-parent wallpapers-link> excludes=<yes>" \
    run_dotfiles_install normal

run_test \
    "dotfiles-sync-failure" \
    7 \
    stdout \
    "calls=<sync>" \
    run_dotfiles_install sync-failure

run_test \
    "dotfiles-rsync-failure" \
    8 \
    stdout \
    "calls=<sync rsync>" \
    run_dotfiles_install rsync-failure

run_test \
    "dotfiles-link-failure" \
    9 \
    stdout \
    "calls=<sync rsync wallpapers-parent wallpapers-link>" \
    run_dotfiles_install link-failure

run_test \
    "dotfiles-refuses-directory-conflict" \
    1 \
    stderr \
    "exists and is not a symbolic link" \
    run_dotfiles_install conflict

printf '%d tests, %d failed\n' "$total" "$failed"

(( failed == 0 ))
