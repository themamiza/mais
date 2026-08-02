#!/usr/bin/env bash

# shellcheck disable=2154

ui_input() {
    if $tui; then
        tui_input "$@"
    else
        text_input "$@"
    fi
}

ui_password() {
    if $tui; then
        tui_password "$@"
    else
        text_password "$@"
    fi
}

ui_yes_no() {
    if $tui; then
        tui_yes_no "$@"
    else
        text_yes_no "$@"
    fi
}

ui_message() {
    if $tui; then
        tui_message "$@"
    else
        text_message "$@"
    fi
}

ui_menu() {
    if $tui; then
        tui_menu "$@"
    else
        text_menu "$@"
    fi
}
