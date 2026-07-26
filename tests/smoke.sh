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
    "programs=ALL" \
    run_parser install-programs --verbose

run_test \
    "detached-program-tag" \
    1 \
    stderr \
    "Invalid option" \
    "$MAIS" install-programs --verbose DEV

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

printf '\n%d passed, %d failed\n' "$passed" "$failed"

(( failed == 0 ))
