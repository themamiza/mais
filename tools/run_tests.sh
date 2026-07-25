#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd -P)" || exit 1
readonly ROOT

release=false

case "${1:-}" in
    "")
        ;;
    "--release")
        release=true
        ;;
    *)
        printf 'Usage: %s [--release]\n' "$(basename "$0")" >&2
        exit 1
        ;;
esac

files=("$ROOT/mais")

while IFS= read -r -d '' file; do
    files+=("$file")
done < <(find "$ROOT/lib" "$ROOT/tests" "$ROOT/tools" -type f -name '*.sh' -print0)

printf 'Checking Bash syntax...\n'
for file in "${files[@]}"; do
    bash -n "$file"
done

if $release; then
    printf 'Building standalone release...\n'
    "$ROOT/tools/build.sh"

    [[ -x "$ROOT/release/mais" ]] || {
        printf 'Standalone release was not created or is not executable.\n' >&2
        exit 1
    }

    printf 'Running release smoke tests...\n'
    "$ROOT/tests/smoke.sh" "$ROOT/release/mais"
else
    printf 'Running modular smoke tests...\n'
    "$ROOT/tests/smoke.sh" "$ROOT/mais"
fi

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
    install_essentials
    install_aurhelper
    update_mirrors

    sync_file
    perform_backup

    ensure_programs_file
    clean_programs_file
    install_package
    suckless_install
    doomemacs_install
    install_programs

    install_dotfiles

    configure_grub
    configure_pacman
    configure_makepkg
    configure_proxychains
    configure_keyd

    clean_home

    command_backup
    command_update_mirrors
    command_install_dotfiles
    command_install_aurhelper
    command_install_programs
    command_configure
    command_experimental_clean_home
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
