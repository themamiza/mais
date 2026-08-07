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
        --scrolltext \
        --yesno "$message" \
        20 \
        76
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

# args: title message tag description [tag description ...]
tui_menu() {
    local title="$1"
    local message="$2"
    shift 2

    whiptail \
        --backtitle "$tui_backtitle" \
        --title "$title" \
        --menu "$message" \
        20 \
        76 \
        12 \
        "$@" \
        3>&1 1>&2 2>&3
}

# args: title message tag display_text [tag display_text ...]
tui_menu_no_tags() {
    local title="$1"
    local message="$2"
    shift 2

    whiptail \
        --backtitle "$tui_backtitle" \
        --title "$title" \
        --notags \
        --menu "$message" \
        20 \
        76 \
        12 \
        "$@" \
        3>&1 1>&2 2>&3
}

# args: title message tag description status [tag description status ...]
tui_checklist() {
    local title="$1"
    local message="$2"
    tui_checklist_width=100

    shift 2

    whiptail \
        --backtitle "$tui_backtitle" \
        --title "$title" \
        --separate-output \
        --checklist "$message" \
        24 \
        "$tui_checklist_width" \
        16 \
        "$@" \
        3>&1 1>&2 2>&3
}
