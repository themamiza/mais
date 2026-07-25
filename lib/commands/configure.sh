#!/usr/bin/env bash

# shellcheck disable=2154

configure_grub() {
    # TODO: This message could be more verbose
    sprint "Configuring grub."
    # These configurations need to be done regardless of having swap.
    sed -i "/^GRUB_TIMEOUT=.*$/s/=.*/=3/;
            /^#GRUB_DISABLE_OS_PROBER=false$/s/#//;
            /^GRUB_DEFAULT=.*$/s/=.*/=saved/;
            /^#GRUB_SAVEDEFAULT=true$/s/#//;
            /^GRUB_CMDLINE_LINUX_DEFAULT=.*$/s/ quiet//;" /etc/default/grub

    sprint "Checking swap partition."
    if ! blkid | grep -q "TYPE=\"swap\""; then
        wprint "Did not find swap partition."
        return
    fi

    # Enable hibernation only if there is a swap device larger than 8G.
    local swapsizegb
    # Grab size of swap partition in GBs.
    swapsizegb="$(blkid | grep "TYPE=\"swap\"" | cut -d" " -f1 | sed "s/://" | xargs lsblk -no SIZE | sed "s/\s\+//;s/.$//;s/\..*//")" 

    if [ "$swapsizegb" -ge 8 ]; then
        sprint "Enabling hibernation."
        grep -q resume /etc/mkinitcpio.conf || {
            sed -i "/^HOOKS=(.*)$/s/)$/ resume)/" /etc/mkinitcpio.conf
            eval "mkinitcpio -P $cmd_suffix"
        }
        grep -q resume /etc/default/grub || {
            local swapuuid; swapuuid=$(blkid | grep swap | grep -Po " UUID=\".*?\"" | sed "s/ //;s/UUID=//;s/\"//g")
            sed -i "/^GRUB_CMDLINE_LINUX_DEFAULT=.*$/s/.$/ resume=UUID=$swapuuid\"/" /etc/default/grub
            eval "grub-mkconfig -o /boot/grub/grub.cfg $cmd_suffix"
        }
    else 
        wprint "Not enough swap for hibernation."
    fi
}

configure_pacman() {
    sprint "Configuring \`pacman\` to do Colors, VerbosePkgLists and ILoveCandy."
    sed -i "/^#Color$/s/#//;
            /^#VerbosePkgLists$/s/#//;" /etc/pacman.conf
    grep -q "ILoveCandy" /etc/pacman.conf || sed -i "/^Color$/a ILoveCandy" /etc/pacman.conf
}

configure_makepkg() {
    sprint "Configuring \`makepkg\` to use all cores for compilation."
    sed -i "/^#MAKEFLAGS/s/^#//;
            s/-j2/-j$(nproc)/;" /etc/makepkg.conf
}

configure_proxychains() {
    sprint "Configuring \`proxychains\` to forward packets to localhost:6969."
    # Remove any previous proxies; then add new configuration.
    sed -i "/^\[ProxyList\]$/q" /etc/proxychains.conf
    printf "# MAIS\nsocks5 127.0.0.1 6969\n" >> /etc/proxychains.conf
}

configure_keyd() {
    sprint "Configuring \`keyd\` to swap escape and capslock."
    printf "# MAIS
[ids]
*

[main]
capslock = esc
esc = capslock\n" > /etc/keyd/default.conf

    eval "systemctl enable --now keyd $cmd_suffix"
    eval "keyd reload $cmd_suffix"
}

command_configure() {
    isRoot || eprint "Only root can configure the system."

    configure_grub
    configure_pacman
    configure_makepkg

    if check_installed proxychains; then
        configure_proxychains
    else
        wprint "\`proxychains\` not installed. Install, then run \`mais configure\`."
    fi

    if check_installed keyd; then
        configure_keyd
    else
        wprint "\`keyd\` not installed. Install, then run \`mais configure\`."
    fi
}
