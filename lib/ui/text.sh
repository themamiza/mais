#!/usr/bin/env bash

# args: title message [default_value]
text_input() {
    local _title="$1"
    local message="$2"
    local default_value="${3:-}"
    local value

    if [[ -n "$default_value" ]]; then
        printf "%s [%s]: " "$message" "$default_value" >&2
    else
        printf "%s: " "$message" >&2
    fi

    read -r value || return 1
    [[ -n "$value" ]] || value="$default_value"
    printf "%s" "$value"
}

# args: title message
text_password() {
    local _title="$1"
    local message="$2"
    local value

    printf "%s: " "$message" >&2
    if ! read -rs value; then
        printf "\n" >&2
        return 1
    fi

    printf "\n" >&2
    printf "%s" "$value"
}

# args: title message
text_yes_no() {
    local _title="$1"
    local message="$2"
    local answer

    printf "%s (Y/N): " "$message" >&2
    read -r answer || return 1
    [[ "$answer" == [yY] ]]
}

# args: title message
text_message() {
    local _title="$1"
    local message="$2"

    wprint "$message"
}

# args: title message tag description [tag description ...]
text_menu() {
    local title="$1"
    local message="$2"
    shift 2

    local choices=()
    local tag
    local description
    local selected

    while (( $# >= 2 )); do
        tag="$1"
        description="$2"

        choices+=("$tag"$'\t'"$description")
        shift 2
    done

    (( ${#choices[@]} > 0 )) || return 1

    ! selected="$(printf "%s\n" "${choices[@]}" | fzf \
                                                    --height=60% \
                                                    --layout=reverse \
                                                    --border \
                                                    --prompt="$title > " \
                                                    --header="$message")" && return 1

    printf "%s" "${selected%%$'\t'*}"
}
