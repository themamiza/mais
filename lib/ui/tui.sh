#!/usr/bin/env bash

tui_backtitle="MAIS"

# args: title message [default_value]
tui_input() {
    local title="$1"
    local message="$2"
    local default_value="${3:-}"

    whiptail \
        --backtitle "$tui_backtitle" \
        --title "$title" \
        --inputbox "$message" \
        10 \
        70 \
        "$default_value" \
        3>&1 1>&2 2>&3
}

# args: title message
tui_password() {
    local title="$1"
    local message="$2"

    whiptail \
        --backtitle "$tui_backtitle" \
        --title "$title" \
        --passwordbox "$message" \
        10 \
        70 \
        3>&1 1>&2 2>&3
}

# args: title message
tui_yes_no() {
    local title="$1"
    local message="$2"

    whiptail \
        --backtitle "$tui_backtitle" \
        --title "$title" \
        --yesno "$message" \
        12 \
        70
}

# args: title message
tui_message() {
    local title="$1"
    local message="$2"

    whiptail \
        --backtitle "$tui_backtitle" \
        --title "$title" \
        --msgbox "$message" \
        12 \
        70
}
