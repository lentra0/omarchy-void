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
  #tlp
  #tlp-rdw
)

install_packages "${SYSTEM_SERVICES[@]}"

# Networking
NETWORKING=(
  NetworkManager
  wpa_supplicant
  wifish
  wpa-cute
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
  udevd
  agetty-tty1
  agetty-tty2
  agetty-tty3
  agetty-tty4
  agetty-tty5
  agetty-tty6
  crond
  seatd
  elogind
  polkitd
  NetworkManager
  bluetoothd
  #tlp
)

if [ -L "/var/service" ] && [ ! -e "/var/service" ]; then
  echo "Fixing broken /var/service symlink..."
  sudo rm -f "/var/service"
  sudo mkdir -p "/run/runit/runsvdir/current"
  sudo ln -sf "/run/runit/runsvdir/current" "/var/service"
fi

if [ ! -e "/var/service" ]; then
  echo "Creating /var/service structure..."
  sudo mkdir -p "/run/runit/runsvdir/current"
  sudo ln -sf "/run/runit/runsvdir/current" "/var/service"
fi

for service in "${SERVICES_TO_ENABLE[@]}"; do
  enable_service "$service"
done

# Disable acpid to avoid conflicts with elogind
if service_exists "acpid"; then
  if service_enabled "acpid"; then
    log_info "Disabling acpid (conflicts with elogind)..."
    disable_service "acpid"
    log_success "acpid disabled - elogind will handle power management"
  fi
fi

module_end
