#!/usr/bin/env bash

# Load a module using a path relative to the repository root.

# Usage example:
#   mais_load_module "lib/core/log.sh"

mais_load_module() {
    local relative_path="$1"
    local module_path="$MAIS_ROOT/$relative_path"

    if [[ ! -r "$module_path" ]]; then
        printf "%s: unable to load module: %s\n" "${program_name:-mais}" "$relative_path" >&2
        return 1
    fi

    # Module paths are controlled internally by mais.
    # shellcheck source=/dev/null
    source "$module_path"
}
