#!/usr/bin/env bash

is_archlinux() {
    command -v "pacman" >/dev/null 2>&1
}
