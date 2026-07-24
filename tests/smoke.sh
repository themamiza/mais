#!/usr/bin/env bash

set -uo pipefail

readonly TEST_ROOT="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1
    pwd -P
)"

readonly MAIS="$TEST_ROOT/mais"
readonly TEST_TMP="$(mktemp -d)"

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

if ! bash -n "$MAIS"; then
    printf 'FAIL: mais has invalid Bash syntax\n'
    exit 1
fi

if ! bash -n "$TEST_ROOT/lib/core/loader.sh"; then
    printf 'FAIL: loader.sh has invalid Bash syntax\n'
    exit 1
fi

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
