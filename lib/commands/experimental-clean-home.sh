#!/usr/bin/env bash

# shellcheck disable=2154

clean_home() {
    # TODO: ask for important applications' history and cache
    # e.g. thumbnails, shell histories, emacs...
    # default to not remove so user can just press enter and be done with it.
    # possibly provide option to remove or not remove by default.
    # TODO: bluetooth history could be useful. try and see if can keep only the last one.
    run_cmd rm -rf \
    "/home/$username/.cache/breezy" \
    "/home/$username/.cache/deno" \
    "/home/$username/.recently-used" \
    "/home/$username/.java" \
    "/home/$username/.mono" \
    || true


    # Harmlesss
    # ~/.local/share/NBTExplorer*
    # ~/.local/share/inxi
    # ~/.local/share/qalculate
    # ~/.local/share/ristretto
    # ~/.local/share/vlc
    # ~/.local/share/xorg/Xorg.*.log.old
    # ~/.local/share/zathura
    # ~/.local/share/Hardcoded\ Software
    # ~/.cache/.bluetoothctl_history-*.tmp
    # ~/.cache/mesa*
    # ~/.cache/go-build
    # ~/.cache/gstreamer-1.0
    # ~/.cache/gtk-4.0
    # ~/.cache/jedi
    # ~/.cache/virt-manager
    # ~/.cache/qtshadercache*
    # ~/.cache/kitty*
    # ~/.local/share/kwalletd
    #
    #
    # Could mess with system
    # ~/.local/share/kdenlive
    # ~/.local/share/simulide
    # ~/.local/share/stalefiles
    # ~/.cache/kdenlive
    # ~/.cache/gimp
    # ~/.cache/nvidia
    # ~/.local/share/flatpak
    #
    # Probably not there
    # ~/.local/share/app.hiddify.com
    #
    # Don't know what makes them
    # ~/.local/share/recently-used.xbel*
    # ~/.local/share/user-places.xbel*
    # ~/.cache/gegl-0.4
    # ~/.cache/glycin
    # ~/.cache/nv
    # ~/.cache/audioCache.kcache
    #
    # Histories
    # Ask for permission
    # Optionally do backups of these before removal
    # ~/.local/share/octave/history
    # ~/.cache/bash
    # ~/.cache/emacs
    # ~/.cache/thumbnails
    # ~/.cache/yazi
    # ~/.cache/fsh
    # ~/.cache/lf
    #
    # Ask for permission
    # ~/.local/share/icons
    # ~/.cache/fontconfig
    #
    # Make sure internet connection is available or you could break your system
    # ~/.local/src
    # ~/.local/state
    # ~/.cache/openjfx
}

command_experimental_clean_home() {
    clean_home
    exit 0
}
