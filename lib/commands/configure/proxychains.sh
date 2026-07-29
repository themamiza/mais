#!/usr/bin/env bash

configure_proxychains() {
    sprint "Configuring \`proxychains\` to forward packets to localhost:6969."
    # Remove any previous proxies; then add new configuration.
    sed -i "/^\[ProxyList\]$/q" /etc/proxychains.conf
    printf "# MAIS\nsocks5 127.0.0.1 6969\n" >> /etc/proxychains.conf
}
