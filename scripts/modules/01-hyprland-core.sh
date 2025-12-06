#!/bin/bash

# Module: Hyprland Core
# Core Hyprland and Wayland packages

module_start "Hyprland Core Installation"

# Add Hyprland Void repository
echo "Adding Hyprland Void repository..."
execute echo "repository=https://raw.githubusercontent.com/Makrennel/hyprland-void/repository-x86_64-glibc" | sudo tee /etc/xbps.d/hyprland-void.conf

# Update repository index
execute sudo xbps-install -S

# Check available Hyprland packages
echo "Checking available Hyprland packages..."
execute xbps-query -Rs hypr

# Core Hyprland packages
HYPRLAND_CORE=(
    hyprland
    hyprland-protocols
    hyprland-qtutils
    xorg-server-xwayland
    xdg-desktop-portal-hyprland
    xdg-desktop-portal
    xdg-utils
    xorg
    wayland
    wayland-protocols
    xdg-desktop-portal-wlr
    xdg-desktop-portal-gtk
)

install_packages "${HYPRLAND_CORE[@]}"

# Add multilib and nonfree repositories
echo "Adding multilib and nonfree repositories..."
install_packages void-repo-multilib void-repo-nonfree
execute sudo xbps-install -S

module_end