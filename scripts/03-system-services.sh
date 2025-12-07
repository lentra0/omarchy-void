#!/bin/bash

# Module: System Services
# System services, networking, authentication

module_start "System Services Installation"

# System services
SYSTEM_SERVICES=(
    dbus
    seatd
    elogind
    polkit
    bluez
    bluez-obex
    cronie
)

install_packages "${SYSTEM_SERVICES[@]}"

# Networking
NETWORKING=(
    wpa_supplicant
    wifish
    wpa-cute
    wpa_gui
)

install_packages "${NETWORKING[@]}"

# Authentication and security
AUTH_PACKAGES=(
    gnome-keyring
    polkit-gnome
)

install_packages "${AUTH_PACKAGES[@]}"

# Filesystem tools
FS_TOOLS=(
    mtpfs
    inotify-tools
)

install_packages "${FS_TOOLS[@]}"

# Enable essential services
echo "Enabling services..."
SERVICES_TO_ENABLE=(
    dbus
    crond
    seatd
    elogind
    polkitd
    bluetoothd
)

for service in "${SERVICES_TO_ENABLE[@]}"; do
    enable_service "$service"
done

module_end