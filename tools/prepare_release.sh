#!/usr/bin/env bash

set -euo pipefail

ROOT="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." \
        >/dev/null 2>&1 &&
        pwd -P
)" || exit 1
readonly ROOT

readonly RELEASE_DIR="$ROOT/release"
readonly RELEASE_FILE="$RELEASE_DIR/mais"
readonly CHECKSUM_FILE="$RELEASE_DIR/mais.sha256"

version="${1:-}"

if ! [[ "$version" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?$ ]]; then
    printf 'Usage: %s vMAJOR.MINOR.PATCH\n' \
        "$(basename "$0")" >&2
    exit 1
fi

if [[ -n "$(git -C "$ROOT" status --porcelain)" ]]; then
    printf 'The Git working tree is not clean.\n' >&2
    exit 1
fi

if git -C "$ROOT" rev-parse \
    --verify \
    --quiet \
    "refs/tags/$version" >/dev/null
then
    printf "Tag '%s' already exists.\n" "$version" >&2
    exit 1
fi

printf 'Preparing release %s...\n' "$version"

"$ROOT/tools/run_tests.sh"
"$ROOT/tools/run_tests.sh" --release

[[ -x "$RELEASE_FILE" ]] || {
    printf 'Standalone release was not created.\n' >&2
    exit 1
}

(
    cd "$RELEASE_DIR"
    sha256sum mais >mais.sha256
    sha256sum --check mais.sha256
)

printf '\nRelease %s is ready.\n' "$version"
printf 'Upload these files to the GitHub Release:\n'
printf '  %s\n' "$RELEASE_FILE"
printf '  %s\n' "$CHECKSUM_FILE"
