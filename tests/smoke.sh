#!/usr/bin/env bash

set -uo pipefail

TEST_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd -P)" || exit 1
readonly TEST_ROOT

MAIS="${1:-$TEST_ROOT/mais}"
readonly MAIS
[[ -f "$MAIS" ]] || {
    printf 'Script under test not found: %s\n' "$MAIS" >&2
    exit 1
}
TEST_TMP="$(mktemp -d)" || exit 1
readonly TEST_TMP

passed=0
failed=0

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
    local actual_status
    local search_file

    "$@" >"$stdout_file" 2>"$stderr_file"
    actual_status=$?

    case "$expected_stream" in
        stdout)
            search_file="$stdout_file"
            ;;
        stderr)
            search_file="$stderr_file"
            ;;
        *)
            printf 'Invalid test stream: %s\n' "$expected_stream" >&2
            return 1
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
        return
    fi

    printf 'PASS: %s\n' "$name"
    ((passed++))
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

        printf "username=%s\n" "${username:-}"
        printf "hostname=%s\n" "${hostname:-}"
        printf "timezone=%s\n" "${timezone:-}"

        printf "aurhelper=%s\n" "${aurhelper:-}"
        printf "programs=%s\n" "${programs:-}"
        printf "dotfiles_url=%s\n" "${dotfiles_url:-}"
        printf "verbose=%s\n" "$verbose"
    ' _ "$TEST_ROOT" "$@"
}

run_program_selection() {
    local tag="$1"

    bash -c '
        set -e

        source "$1"

        programs_file="$2/programs.csv"
        programs_to_install="$2/programs.tmp"

        cat >"$programs_file.clean" <<EOF
|x11|xorg-server|"X11 server"
Suckless|dwm|dwm|"Window manager"
|wayland|wl-clipboard|"Wayland clipboard"
|hyprland|hyprland|"Wayland compositor"
|dev|emacs|"Development editor"
|python|python|"Python language"
|virt|qemu-full|"Virtual machine package"
|extra|virt-viewer|"Description mentions VIRT"
||base-package|"Always installed"
EOF

        lspci() {
            return 1
        }

        selected=()

        install_package() {
            selected+=("$1")
        }

        install_programs "$3"

        printf "selected=<%s>\n" "${selected[*]}"
    ' _ \
        "$TEST_ROOT/lib/commands/install-programs.sh" \
        "$TEST_TMP" \
        "$tag"
}

run_package_lookup() {
    bash -c '
        set -e

        source "$1"

        programs_file="$2/programs.csv"

        cat >"$programs_file.clean" <<EOF
|extra|alacritty|"Terminal emulator"
AUR|extra|alacritty-theme-git|"Color themes"
EOF

        check_installed() {
            return 1
        }

        calls=()

        pacman_install() {
            calls+=("pacman:$1")
        }

        aur_install() {
            calls+=("aur:$1")
        }

        suckless_install() {
            calls+=("suckless:$1")
        }

        doomemacs_install() {
            calls+=("doom:$1")
        }

        install_package alacritty

        printf "calls=<%s>\n" "${calls[*]}"
    ' _ \
        "$TEST_ROOT/lib/commands/install-programs.sh" \
        "$TEST_TMP"
}

run_git_sync() {
    local repository_state="$1"

    bash -c '
        source "$1"

        destination="$2/repository-$3"
        repository_state="$3"
        calls=()

        rm -rf "$destination"

        case "$repository_state" in
            existing)
                mkdir -p "$destination/.git"
                ;;
            non-git)
                mkdir -p "$destination"
                ;;
        esac

        run_cmd() {
            case " $* " in
                *" mkdir -p "*) calls+=("mkdir");;
                *" git -C "*" pull --ff-only "*) calls+=("pull");;
                *" git clone "*) calls+=("clone");;
            esac
        }

        eprint() {
            printf "%s\n" "$1" >&2
            exit 1
        }

        sync_git_repo \
            testuser \
            https://example.com/repository.git \
            "$destination"

        printf "calls=<%s>\n" "${calls[*]}"
    ' _ \
        "$TEST_ROOT/lib/core/run.sh" \
        "$TEST_TMP" \
        "$repository_state"
}

run_arch_package_command() {
    local operation="$1"

    bash -c '
        source "$1"

        operation="$3"
        log_file="$2/arch-package-$operation.log"
        : > "$log_file"

        username=testuser
        aurhelper=yay

        nprint() {
            :
        }

        check_installed() {
            return 1
        }

        run_cmd() {
            printf "run:%s\n" "$*" >> "$log_file"
        }

        sync_git_repo() {
            printf "sync:%s\n" "$*" >> "$log_file"
        }

        cd() {
            printf "cd:%s\n" "$1" >> "$log_file"
            return 0
        }

        case "$operation" in
            pacman)
                pacman_install example-package "Example package"
                ;;
            aur)
                aur_install example-aur-package "Example AUR package"
                ;;
            aurhelper)
                install_aurhelper
                ;;
            mirrors)
                update_mirrors
                ;;
        esac

        calls="$(tr "\n" ";" < "$log_file")"
        calls="${calls%;}"

        printf "calls=<%s>\n" "$calls"
    ' _ \
        "$TEST_ROOT/lib/distro/arch.sh" \
        "$TEST_TMP" \
        "$operation"
}

run_sudoers_install() {
    bash -c '
        source "$1"

        run_cmd() {
            local input
            IFS= read -r input

            printf "record=<%s|%s>\n" "$*" "$input"
        }

        install_sudoers_file \
            /tmp/mais-sudoers \
            "%wheel ALL=(ALL) NOPASSWD: ALL"
    ' _ "$TEST_ROOT/lib/core/sudo.sh"
}

run_arch_install_dispatch() {
    local mode="$1"
    local mounted="${2:-true}"

    bash -c '
        source "$1"

        partition_mode="$2"
        mounted="$3"

        is_archlinux() {
            return 0
        }

        isRoot() {
            return 0
        }

        ensure_mount_point() {
            return 0
        }

        yes_no() {
            return 0
        }

        mountpoint() {
            [[ "$mounted" == true ]]
        }

        partition_vm() {
            printf "partition=vm\n"
        }

        partition_main() {
            printf "partition=main\n"
        }

        partition_x220() {
            printf "partition=x220\n"
        }

        arch_install() {
            printf "arch-install=yes\n"
        }

        eprint() {
            printf "%s\n" "$1" >&2
            exit 1
        }

        command_arch_install
    ' _ \
        "$TEST_ROOT/lib/commands/arch-install.sh" \
        "$mode" \
        "$mounted"
}

run_grub_hibernation_helpers() {
    bash -c '
        source "$1/lib/core/validate.sh"
        source "$1/lib/commands/configure/grub.sh"

        test_dir="$2/grub-hibernation-helpers"
        rm -rf "$test_dir"
        mkdir -p "$test_dir"

        grub_power_state_file="$test_dir/power-state"
        grub_image_size_file="$test_dir/image-size"
        grub_meminfo_file="$test_dir/meminfo"
        grub_swaps_file="$test_dir/swaps"

        printf "freeze mem disk\n" \
            > "$grub_power_state_file"

        printf "%d\n" "$((4 * 1024 * 1024 * 1024))" \
            > "$grub_image_size_file"

        printf "MemTotal: 16777216 kB\n" \
            > "$grub_meminfo_file"

        cat > "$grub_swaps_file" <<EOF
Filename Type Size Used Priority
/dev/zram0 partition 8388608 0 100
/swapfile file 16777216 0 -2
/dev/sda2 partition 4194304 0 -2
/dev/nvme0n1p3 partition 6291456 0 -3
EOF

        grub_block_type() {
            case "$1" in
                /dev/zram0)
                    printf "disk\n"
                    ;;
                *)
                    printf "part\n"
                    ;;
            esac
        }

        printf "number=<%s>\n" \
            "$(is_number 12345 && printf yes || printf no)"

        printf "can-hibernate=<%s>\n" \
            "$(can_hibernate && printf yes || printf no)"

        printf "required=<%s>\n" \
            "$(hibernation_required_swap_gb)"

        printf "swap=<%s>\n" \
            "$(largest_active_swap_partition)"
    ' _ "$TEST_ROOT" "$TEST_TMP"
}

run_grub_hibernation_configuration() {
    bash -c '
        source "$1/lib/core/validate.sh"
        source "$1/lib/commands/configure/grub.sh"

        test_dir="$2/grub-hibernation-config"
        rm -rf "$test_dir"
        mkdir -p "$test_dir"

        grub_defaults_file="$test_dir/default-grub"
        grub_mkinitcpio_file="$test_dir/mkinitcpio.conf"
        grub_output_file="$test_dir/grub.cfg"
        grub_power_state_file="$test_dir/power-state"
        grub_image_size_file="$test_dir/image-size"
        grub_meminfo_file="$test_dir/meminfo"
        grub_swaps_file="$test_dir/swaps"

        cat > "$grub_defaults_file" <<EOF
GRUB_TIMEOUT=5
#GRUB_DISABLE_OS_PROBER=false
GRUB_DEFAULT=0
#GRUB_SAVEDEFAULT=true
GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"
EOF

        printf "HOOKS=(base udev autodetect fsck)\n" \
            > "$grub_mkinitcpio_file"

        printf "freeze mem disk\n" \
            > "$grub_power_state_file"

        printf "%d\n" "$((4 * 1024 * 1024 * 1024))" \
            > "$grub_image_size_file"

        printf "MemTotal: 16777216 kB\n" \
            > "$grub_meminfo_file"

        cat > "$grub_swaps_file" <<EOF
Filename Type Size Used Priority
/dev/sda2 partition 6291456 0 -2
EOF

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
            printf "warning=<%s>\n" "$1"
        }

        calls=()

        run_cmd() {
            calls+=("$*")
        }

        configure_grub

        printf "grub=<%s>\n" \
            "$(grep "^GRUB_CMDLINE_LINUX_DEFAULT=" \
                "$grub_defaults_file")"

        printf "hooks=<%s>\n" \
            "$(grep "^HOOKS=" "$grub_mkinitcpio_file")"

        printf "calls=<%s>\n" \
            "$(IFS=";"; printf "%s" "${calls[*]}")"
    ' _ "$TEST_ROOT" "$TEST_TMP"
}

run_grub_existing_resume_configuration() {
    bash -c '
        source "$1/lib/core/validate.sh"
        source "$1/lib/commands/configure/grub.sh"

        test_dir="$2/grub-existing-resume"
        rm -rf "$test_dir"
        mkdir -p "$test_dir"

        grub_defaults_file="$test_dir/default-grub"
        grub_mkinitcpio_file="$test_dir/mkinitcpio.conf"
        grub_output_file="$test_dir/grub.cfg"
        grub_power_state_file="$test_dir/power-state"
        grub_image_size_file="$test_dir/image-size"
        grub_meminfo_file="$test_dir/meminfo"
        grub_swaps_file="$test_dir/swaps"

        cat > "$grub_defaults_file" <<EOF
GRUB_TIMEOUT=5
GRUB_DEFAULT=0
GRUB_CMDLINE_LINUX_DEFAULT="resume=UUID=old-uuid loglevel=3"
EOF

        printf "HOOKS=(base udev autodetect resume fsck)\n" \
            > "$grub_mkinitcpio_file"

        printf "freeze mem disk\n" \
            > "$grub_power_state_file"

        printf "%d\n" "$((4 * 1024 * 1024 * 1024))" \
            > "$grub_image_size_file"

        printf "MemTotal: 16777216 kB\n" \
            > "$grub_meminfo_file"

        cat > "$grub_swaps_file" <<EOF
Filename Type Size Used Priority
/dev/sda2 partition 6291456 0 -2
EOF

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
            printf "warning=<%s>\n" "$1"
        }

        run_cmd() {
            :
        }

        configure_grub

        grub_line="$(
            grep "^GRUB_CMDLINE_LINUX_DEFAULT=" \
                "$grub_defaults_file"
        )"

        resume_count="$(
            grep -o "resume=" <<< "$grub_line" |
                wc -l
        )"

        printf "grub=<%s>\n" "$grub_line"
        printf "resume-count=<%s>\n" "$resume_count"
    ' _ "$TEST_ROOT" "$TEST_TMP"
}

run_grub_without_swap() {
    bash -c '
        source "$1/lib/core/validate.sh"
        source "$1/lib/commands/configure/grub.sh"

        test_dir="$2/grub-without-swap"
        rm -rf "$test_dir"
        mkdir -p "$test_dir"

        grub_defaults_file="$test_dir/default-grub"
        grub_mkinitcpio_file="$test_dir/mkinitcpio.conf"
        grub_output_file="$test_dir/grub.cfg"
        grub_power_state_file="$test_dir/power-state"
        grub_image_size_file="$test_dir/image-size"
        grub_meminfo_file="$test_dir/meminfo"
        grub_swaps_file="$test_dir/swaps"

        cat > "$grub_defaults_file" <<EOF
GRUB_TIMEOUT=5
GRUB_DEFAULT=0
GRUB_CMDLINE_LINUX_DEFAULT="quiet"
EOF

        printf "HOOKS=(base udev fsck)\n" \
            > "$grub_mkinitcpio_file"

        printf "freeze mem disk\n" \
            > "$grub_power_state_file"

        printf "%d\n" "$((4 * 1024 * 1024 * 1024))" \
            > "$grub_image_size_file"

        printf "MemTotal: 16777216 kB\n" \
            > "$grub_meminfo_file"

        printf "Filename Type Size Used Priority\n" \
            > "$grub_swaps_file"

        sprint() {
            :
        }

        wprint() {
            :
        }

        run_cmd() {
            printf "run=<%s>\n" "$*"
        }

        configure_grub
    ' _ "$TEST_ROOT" "$TEST_TMP"
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
        wallpapers_dir="$user_home/fl/Pix/Wallpapers"
        wallpapers_link="$user_home/.local/share/wallpapers"

        mkdir -p "$user_home" "$wallpapers_dir"

        calls=()
        rsync_excludes=no

        sprint() {
            :
        }

        wprint() {
            printf "warning=<%s>\n" "$1" >&2
        }

        sync_git_repo() {
            calls+=(sync)

            if [[ "$scenario" == sync-failure ]]; then
                return 7
            fi

            return 0
        }

        run_cmd() {
            local action=other
            local argument
            local destination="${!#}"
            local required_option
            local found
            local required_rsync_options=(
                --exclude=/.git/
                --exclude=/.gitignore
                --exclude=/.gitmodules
                --exclude=/LICENSE
                --exclude=/README.md
            )

            for argument in "$@"; do
                if [[ "$argument" == "rsync" ]]; then
                    action=rsync
                    break
                fi

                if [[ "$argument" == "mkdir" ]]; then
                    action=wallpapers-parent
                    break
                fi

                if [[ "$argument" == "ln" ]]; then
                    if [[ "$destination" == "$wallpapers_link" ]]; then
                        action=wallpapers-link
                    else
                        action=v2rayn-link
                    fi

                    break
                fi
            done

            if [[ "$action" == "rsync" ]]; then
                rsync_excludes=yes

                for required_option in "${required_rsync_options[@]}"; do
                    found=false

                    for argument in "$@"; do
                        if [[ "$argument" == "$required_option" ]]; then
                            found=true
                            break
                        fi
                    done

                    $found || rsync_excludes=no
                done
            fi

            calls+=("$action")

            if [[ "$scenario" == "rsync-failure" &&
                "$action" == "rsync" ]]; then
            return 8
            fi

            if [[ "$scenario" == "link-failure" &&
                "$action" == "wallpapers-link" ]]; then
            return 9
            fi

            return 0
        }

        if [[ "$scenario" == local ]]; then
            mkdir -p "$user_home/rp/dotfiles"
        fi

        if [[ "$scenario" == v2rayn ]]; then
            touch "$dotfiles_v2rayn_binary"
        fi

        if [[ "$scenario" == wallpaper-conflict ]]; then
            mkdir -p "$wallpapers_link"
        fi

        install_dotfiles
        status=$?

        printf "calls=<%s>\n" "${calls[*]}"
        printf "rsync-excludes=<%s>\n" "$rsync_excludes"
        exit "$status"
    ' _ "$TEST_ROOT" "$TEST_TMP" "$scenario"
}

run_dotfiles_command_failure() {
    bash -c '
        source "$1/lib/commands/install-dotfiles.sh"

        isRoot() {
            return 0
        }

        wheel_can_sudo() {
            :
        }

        ask_username() {
            :
        }

        install_essentials() {
            :
        }

        install_dotfiles() {
            printf "dotfiles=<failed>\n"
            return 7
        }

        command_install_dotfiles
    ' _ "$TEST_ROOT"
}

syntax_files=(
    "$MAIS"
    "$TEST_ROOT/lib/core/loader.sh"
    "$TEST_ROOT/lib/core/config.sh"
    "$TEST_ROOT/lib/core/log.sh"
    "$TEST_ROOT/lib/core/validate.sh"
    "$TEST_ROOT/lib/core/prompt.sh"
    "$TEST_ROOT/lib/core/run.sh"
    "$TEST_ROOT/lib/core/sudo.sh"

    "$TEST_ROOT/lib/distro/detect.sh"
    "$TEST_ROOT/lib/distro/arch.sh"

    "$TEST_ROOT/lib/cli/help.sh"
    "$TEST_ROOT/lib/cli/parser.sh"
    "$TEST_ROOT/lib/cli/dispatch.sh"

    "$TEST_ROOT/lib/commands/arch-install.sh"
    "$TEST_ROOT/lib/commands/backup.sh"
    "$TEST_ROOT/lib/commands/update-mirrors.sh"
    "$TEST_ROOT/lib/commands/install-dotfiles.sh"
    "$TEST_ROOT/lib/commands/install-aurhelper.sh"
    "$TEST_ROOT/lib/commands/install-programs.sh"
    "$TEST_ROOT/lib/commands/configure/grub.sh"
    "$TEST_ROOT/lib/commands/configure/pacman.sh"
    "$TEST_ROOT/lib/commands/configure/makepkg.sh"
    "$TEST_ROOT/lib/commands/configure/proxychains.sh"
    "$TEST_ROOT/lib/commands/configure/keyd.sh"
    "$TEST_ROOT/lib/commands/configure.sh"
    "$TEST_ROOT/lib/commands/experimental-clean-home.sh"
    "$TEST_ROOT/lib/commands/install.sh"
)

for shell_file in "${syntax_files[@]}"; do
    if ! bash -n "$shell_file"; then
        printf 'FAIL: %s has invalid Bash syntax\n' "$shell_file"
        exit 1
    fi
done

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
    "$MAIS" definitely-not-a-command

# $1 must be expanded by the child shell, not this script.
# Therefore using single quotes here.
# shellcheck disable=2016
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
    "verbose-before-command" \
    0 \
    stdout \
    "Usage:" \
    "$MAIS" --verbose help

run_test \
    "verbose-after-command" \
    0 \
    stdout \
    "Usage:" \
    "$MAIS" help --verbose

run_test \
    "complete-command-before-option" \
    0 \
    stdout \
    "aurhelper=yay" \
    run_parser install-aurhelper yay --verbose

run_test \
    "option-cannot-split-required-argument" \
    1 \
    stderr \
    "should provide an 'aurhelper'" \
    "$MAIS" install-aurhelper --verbose yay

run_test \
    "option-cannot-split-partition-mode" \
    1 \
    stderr \
    "should provide a 'partition_mode'" \
    "$MAIS" arch-install --verbose vm

run_test \
    "optional-dotfiles-argument-omitted" \
    0 \
    stdout \
    "dotfiles_url=https://github.com/themamiza/dotfiles" \
    run_parser install-dotfiles --verbose

run_test \
    "detached-dotfiles-argument" \
    1 \
    stderr \
    "Invalid option" \
    "$MAIS" install-dotfiles --verbose https://example.com/dotfiles

run_test \
    "optional-program-tag-omitted" \
    0 \
    stdout \
    "programs=all" \
    run_parser install-programs --verbose

run_test \
    "lowercase-program-tag" \
    0 \
    stdout \
    "programs=dev" \
    run_parser install-programs dev

run_test \
    "uppercase-program-tag-rejected" \
    1 \
    stderr \
    "'DEV' is not a valid tag" \
    "$MAIS" install-programs DEV

run_test \
    "detached-program-tag" \
    1 \
    stderr \
    "Invalid option" \
    "$MAIS" install-programs --verbose dev

run_test \
    "virt-program-selection" \
    0 \
    stdout \
    "selected=<qemu-full base-package>" \
    run_program_selection virt

run_test \
    "dwm-program-selection" \
    0 \
    stdout \
    "selected=<xorg-server dwm base-package>" \
    run_program_selection dwm

run_test \
    "hyprland-program-selection" \
    0 \
    stdout \
    "selected=<wl-clipboard hyprland base-package>" \
    run_program_selection hyprland

run_test \
    "dev-program-selection" \
    0 \
    stdout \
    "selected=<emacs python base-package>" \
    run_program_selection dev

run_test \
    "all-program-selection" \
    0 \
    stdout \
    "selected=<xorg-server dwm wl-clipboard hyprland emacs python qemu-full virt-viewer base-package>" \
    run_program_selection all

run_test \
    "exact-package-lookup" \
    0 \
    stdout \
    "calls=<pacman:alacritty>" \
    run_package_lookup

run_test \
    "pacman-install-uses-run-command" \
    0 \
    stdout \
    "calls=<run:pacman -S --noconfirm example-package>" \
    run_arch_package_command pacman

run_test \
    "aur-install-uses-run-command" \
    0 \
    stdout \
    "calls=<run:sudo -u testuser yay -S --noconfirm example-aur-package>" \
    run_arch_package_command aur

run_test \
    "aurhelper-uses-git-sync-and-run-command" \
    0 \
    stdout \
    "calls=<sync:testuser https://aur.archlinux.org/yay.git /home/testuser/.local/src/yay;cd:/home/testuser/.local/src/yay;run:sudo -u testuser makepkg --noconfirm -si>" \
    run_arch_package_command aurhelper

run_test \
    "mirror-update-uses-run-command" \
    0 \
    stdout \
    "calls=<run:reflector --country Germany --latest 16 --protocol https --sort rate --save /etc/pacman.d/mirrorlist>" \
    run_arch_package_command mirrors

run_test \
    "options-without-command" \
    1 \
    stderr \
    "No command was provided." \
    "$MAIS" --verbose

run_test \
    "multiple-commands" \
    1 \
    stderr \
    "Only one command can be provided" \
    "$MAIS" help configure

run_test \
    "duplicate-command" \
    1 \
    stderr \
    "Only one command can be provided" \
    "$MAIS" help help

run_test \
    "option-between-commands" \
    1 \
    stderr \
    "Only one command can be provided" \
    "$MAIS" help --verbose configure

run_test \
    "valid-username-before-command" \
    0 \
    stdout \
    "username=testuser" \
    run_parser --username testuser help

run_test \
    "command-cannot-be-username" \
    1 \
    stderr \
    "You should provide a username" \
    "$MAIS" help --username configure

run_test \
    "command-cannot-be-hostname" \
    1 \
    stderr \
    "You should provide a hostname" \
    "$MAIS" configure --hostname install

run_test \
    "command-cannot-be-timezone" \
    1 \
    stderr \
    "You should provide a timezone" \
    "$MAIS" help --timezone configure

run_test \
    "option-cannot-be-username" \
    1 \
    stderr \
    "You should provide a username" \
    "$MAIS" help --username --verbose

# shellcheck disable=2016
run_test \
   "successful-command-dispatch" \
   0 \
   stdout \
   "dispatch completed" \
   bash -c '
       set -e
       source "$1"

       help=""
       args_arch_install=""
       args_install_dotfiles=""
       args_install_aurhelper=""
       args_install_programs=""
       args_configure=true
       args_clean_home=""
       args_backup=""
       args_update_mirrors=""
       args_install=""

       command_configure() {
           return 0
       }

       dispatch_commands
       printf "dispatch completed\n"
   ' _ "$TEST_ROOT/lib/cli/dispatch.sh"

# shellcheck disable=2016
run_test \
    "failed-command-dispatch" \
    7 \
    stderr \
    "command failed" \
    bash -c '
        set -e
        source "$1"

        help=""
        args_arch_install=""
        args_install_dotfiles=""
        args_install_aurhelper=""
        args_install_programs=""
        args_configure=true
        args_clean_home=""
        args_backup=""
        args_update_mirrors=""
        args_install=""

        command_configure() {
            printf "command failed\n" >&2
            return 7
        }

        dispatch_commands
    ' _ "$TEST_ROOT/lib/cli/dispatch.sh"

# shellcheck disable=2016
run_test \
    "run-command-suppresses-output" \
    0 \
    stdout \
    "output=<>" \
    bash -c '
        source "$1"

        verbose=false
        output="$(run_cmd bash -c "printf visible; printf error >&2")"

        printf "output=<%s>\n" "$output"
    ' _ "$TEST_ROOT/lib/core/run.sh"

# shellcheck disable=2016
run_test \
    "run-command-shows-output" \
    0 \
    stdout \
    "output=<visible>" \
    bash -c '
        source "$1"

        verbose=true
        output="$(run_cmd printf visible)"

        printf "output=<%s>\n" "$output"
    ' _ "$TEST_ROOT/lib/core/run.sh"

# shellcheck disable=2016
run_test \
    "run-command-preserves-status" \
    0 \
    stdout \
    "status=7" \
    bash -c '
        source "$1"

        verbose=false

        run_cmd bash -c "exit 7"
        status=$?

        printf "status=%d\n" "$status"
    ' _ "$TEST_ROOT/lib/core/run.sh"

run_test \
    "git-sync-clones-missing-repository" \
    0 \
    stdout \
    "calls=<mkdir clone>" \
    run_git_sync missing

run_test \
    "git-sync-rejects-non-git-directory" \
    1 \
    stderr \
    "exists but is not a Git repository" \
    run_git_sync non-git

run_test \
    "git-sync-updates-existing-repository" \
    0 \
    stdout \
    "calls=<mkdir pull>" \
    run_git_sync existing

run_test \
    "sudoers-file-uses-command-input" \
    0 \
    stdout \
    "record=<install -m 0440 /dev/stdin /tmp/mais-sudoers|%wheel ALL=(ALL) NOPASSWD: ALL>" \
    run_sudoers_install

run_test \
    "arch-install-dispatches-vm-partitioning" \
    0 \
    stdout \
    "partition=vm" \
    run_arch_install_dispatch vm

run_test \
    "mounted-mode-requires-mounted-root" \
    1 \
    stderr \
    "requires an existing filesystem mounted at '/mnt'" \
    run_arch_install_dispatch mounted false

run_test \
    "number-helper-accepts-digits" \
    0 \
    stdout \
    "number=<yes>" \
    run_grub_hibernation_helpers

run_test \
    "kernel-hibernation-support-detected" \
    0 \
    stdout \
    "can-hibernate=<yes>" \
    run_grub_hibernation_helpers

run_test \
    "hibernation-requirement-returned-in-gb" \
    0 \
    stdout \
    "required=<4.500000>" \
    run_grub_hibernation_helpers

run_test \
    "largest-plain-swap-partition-selected" \
    0 \
    stdout \
    "swap=</dev/nvme0n1p3 6.000000>" \
    run_grub_hibernation_helpers

run_test \
    "grub-adds-resume-uuid" \
    0 \
    stdout \
    'grub=<GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3'\
' resume=UUID=test-swap-uuid">' \
    run_grub_hibernation_configuration

run_test \
    "mkinitcpio-resume-hook-added" \
    0 \
    stdout \
    "hooks=<HOOKS=(base udev autodetect resume fsck)>" \
    run_grub_hibernation_configuration

run_test \
    "hibernation-regenerates-initramfs" \
    0 \
    stdout \
    "mkinitcpio -P" \
    run_grub_hibernation_configuration

run_test \
    "grub-configuration-is-regenerated" \
    0 \
    stdout \
    "grub-mkconfig -o" \
    run_grub_hibernation_configuration

run_test \
    "grub-replaces-existing-resume-uuid" \
    0 \
    stdout \
    'grub=<GRUB_CMDLINE_LINUX_DEFAULT="'\
'resume=UUID=test-swap-uuid loglevel=3">' \
    run_grub_existing_resume_configuration

run_test \
    "grub-does-not-duplicate-resume-option" \
    0 \
    stdout \
    "resume-count=<1>" \
    run_grub_existing_resume_configuration

run_test \
    "grub-regenerated-without-swap" \
    0 \
    stdout \
    "run=<grub-mkconfig -o" \
    run_grub_without_swap

run_test \
    "dotfiles-remote-install-succeeds" \
    0 \
    stdout \
    "calls=<sync rsync wallpapers-parent wallpapers-link>" \
    run_dotfiles_install remote

run_test \
    "dotfiles-rsync-excludes-repository-files" \
    0 \
    stdout \
    "rsync-excludes=<yes>" \
    run_dotfiles_install remote

run_test \
    "dotfiles-local-repository-skips-sync" \
    0 \
    stdout \
    "calls=<rsync wallpapers-parent wallpapers-link>" \
    run_dotfiles_install local

run_test \
    "dotfiles-sync-failure-propagates" \
    7 \
    stdout \
    "calls=<sync>" \
    run_dotfiles_install sync-failure

run_test \
    "dotfiles-rsync-failure-propagates" \
    8 \
    stdout \
    "calls=<sync rsync>" \
    run_dotfiles_install rsync-failure

run_test \
    "dotfiles-wallpaper-link-is-created" \
    0 \
    stdout \
    "wallpapers-link" \
    run_dotfiles_install remote

run_test \
    "dotfiles-wallpaper-link-failure-propagates" \
    9 \
    stdout \
    "calls=<sync rsync wallpapers-parent wallpapers-link>" \
    run_dotfiles_install link-failure

run_test \
    "dotfiles-refuses-wallpaper-directory-conflict" \
    1 \
    stderr \
    "exists and is not a symbolic link" \
    run_dotfiles_install wallpaper-conflict

run_test \
    "dotfiles-optional-v2rayn-link-is-created" \
    0 \
    stdout \
    "calls=<sync rsync v2rayn-link wallpapers-parent wallpapers-link>" \
    run_dotfiles_install v2rayn

printf '\n%d passed, %d failed\n' "$passed" "$failed"

(( failed == 0 ))
