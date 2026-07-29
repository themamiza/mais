#!/usr/bin/env bash

configure_makepkg() {
    sprint "Configuring \`makepkg\` to use all cores for compilation."
    sed -i "/^#MAKEFLAGS/s/^#//;
            s/-j2/-j$(nproc)/;" /etc/makepkg.conf
}
