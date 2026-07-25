#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd -P)" || exit 1
readonly ROOT

readonly MAIN="$ROOT/mais"
readonly RELEASE_DIR="$ROOT/release"
readonly OUTPUT="$RELEASE_DIR/mais"

readonly START_MARKER="# BEGIN MAIS MODULE LOADER"
readonly END_MARKER="# END MAIS MODULE LOADER"

[[ -f "$MAIN" ]] || {
    printf 'Main script not found: %s\n' "$MAIN" >&2
    exit 1
}

grep -qxF "$START_MARKER" "$MAIN" || {
    printf 'Start marker not found in %s\n' "$MAIN" >&2
    exit 1
}

grep -qxF "$END_MARKER" "$MAIN" || {
    printf 'End marker not found in %s\n' "$MAIN" >&2
    exit 1
}

mapfile -t modules < <(
    sed -n \
        "/^${START_MARKER}$/,/^${END_MARKER}$/p" \
        "$MAIN" |
        sed -n \
            's/^[[:space:]]*mais_load_module[[:space:]]*"\([^"]*\)".*/\1/p'
)

[[ "${#modules[@]}" -gt 0 ]] || {
    printf 'No modules found in %s\n' "$MAIN" >&2
    exit 1
}

mkdir -p "$RELEASE_DIR"

temporary_output="$(mktemp "$RELEASE_DIR/.mais.XXXXXX")" || exit 1

cleanup() {
    rm -f "$temporary_output"
}

trap cleanup EXIT HUP INT QUIT TERM

# Copy the main script up to, but not including, the loader block.
awk -v marker="$START_MARKER" '
    $0 == marker {
        exit
    }

    {
        print
    }
' "$MAIN" > "$temporary_output"

for module in "${modules[@]}"; do
    module_path="$ROOT/$module"

    [[ -f "$module_path" ]] || {
        printf 'Module not found: %s\n' "$module_path" >&2
        exit 1
    }

    printf '\n# --- %s ---\n' "$module" >> "$temporary_output"

    # Module shebangs are unnecessary inside the standalone script.
    sed '1{/^#!\/usr\/bin\/env bash$/d;}' \
        "$module_path" >> "$temporary_output"
done

# Copy everything after the loader block.
awk -v marker="$END_MARKER" '
    found {
        print
    }

    $0 == marker {
        found = 1
    }
' "$MAIN" >> "$temporary_output"

if grep -qE \
    '^[[:space:]]*(source .*lib/core/loader\.sh|mais_load_module)' \
    "$temporary_output"; then
    printf 'Generated release still contains module-loading commands.\n' >&2
    exit 1
fi

bash -n "$temporary_output"
chmod 755 "$temporary_output"
mv "$temporary_output" "$OUTPUT"

printf 'Built standalone release: %s\n' "$OUTPUT"
