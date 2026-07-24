#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd -P)" || exit 1
readonly ROOT

files=("$ROOT/mais")

while IFS= read -r -d '' file; do
    files+=("$file")
done < <(find "$ROOT/lib" "$ROOT/tests" "$ROOT/tools" -type f -name '*.sh' -print0)

printf 'Checking Bash syntax...\n'
for file in "${files[@]}"; do
    bash -n "$file"
done

printf 'Running smoke tests...\n'
"$ROOT/tests/smoke.sh"

printf 'Running ShellCheck...\n'
command -v shellcheck >/dev/null 2>&1 || {
    printf 'shellcheck is not installed.\n' >&2
    exit 1
}
shellcheck "${files[@]}"

printf 'Checking extracted function locations...\n'

functions=(
    check_installed

    is_archlinux
    pacman_install
    aur_install
    install_aurhelper
    update_mirrors

    sync_file
    perform_backup

    command_backup
    command_update_mirrors
)

for function_name in "${functions[@]}"; do
    matches="$(grep -RnsE "^[[:space:]]*${function_name}[[:space:]]*\\(\\)" "$ROOT/mais" "$ROOT/lib" || true)"
    count="$(grep -c . <<<"$matches" || true)"

    if [[ "$count" -ne 1 ]]; then
        printf "Expected '%s' to be defined once, found %d:\n%s\n" \
            "$function_name" "$count" "$matches" >&2
        exit 1
    fi
done

printf 'All checks passed.\n'
