#!/usr/bin/env bash

# shellcheck disable=2154

# NormalPRINT: Print information (can also be notifying) to stdout. (just respects 'quiet')
nprint() {
    $quiet && return
    printf "%s: %b\n" "$program_name" "$1"
}

# SilentPRINT: Same as 'nprint' but respect 'verbose' and 'quiet'.
sprint() {
    ! $verbose || $quiet && return
    printf "%s: %b\n" "$program_name" "$1"
}

# WarningPRINT: Print warnings to stderr but don't exit.
wprint() {
    printf "%s: %b\n" "$program_name" "$1" >&2
}

# ErrorPRINT: Print error to stderr and exit with code (second argument).
eprint() {
    local code=${2:-1}
    printf "%s: %b\n" "$program_name" "$1" >&2
    exit "$code"
}

