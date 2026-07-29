#!/usr/bin/env bash

configure_keyd() {
    sprint "Configuring \`keyd\` to swap escape and capslock."
    printf "# MAIS
[ids]
*

[main]
capslock = esc
esc = capslock\n" > /etc/keyd/default.conf

    run_cmd systemctl enable --now keyd
    run_cmd keyd reload
}
