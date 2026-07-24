#!/usr/bin/env bash

set -uo pipefail

TEST_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd -P)" || exit 1
readonly TEST_ROOT

readonly MAIS="$TEST_ROOT/mais"
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

syntax_files=(
    "$MAIS"
    "$TEST_ROOT/lib/core/loader.sh"
    "$TEST_ROOT/lib/core/config.sh"
    "$TEST_ROOT/lib/core/log.sh"
    "$TEST_ROOT/lib/core/validate.sh"
    "$TEST_ROOT/lib/core/prompt.sh"
    "$TEST_ROOT/lib/core/run.sh"
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

printf '\n%d passed, %d failed\n' "$passed" "$failed"

(( failed == 0 ))
