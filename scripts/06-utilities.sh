#!/bin/bash

# Module: Utilities
# Various utilities and applications

module_start "Utilities Installation"

# System monitoring
MONITORING=(
  fastfetch
  btop
  nvtop
  brightnessctl
)

install_packages "${MONITORING[@]}"

# Modern CLI tools
MODERN_CLI=(
  bat
  eza
  lazygit
  lazydocker
)

install_packages "${MODERN_CLI[@]}"

# File managers
FILE_MANAGERS=(
  yazi
  nemo
)

install_packages "${FILE_MANAGERS[@]}"

# Archive tools
ARCHIVE_TOOLS=(
  zip
  unzip
  7zip
  p7zip
  tar
  gzip
  xz
  zstd
  bzip3
  cpio
)

install_packages "${ARCHIVE_TOOLS[@]}"

# Editors
EDITORS=(
  nano
  vim
  neovim
  kwrite
)

install_packages "${EDITORS[@]}"

# Input method
INPUT_METHOD=(
  fcitx5
  fcitx5-configtool
  fcitx5-gtk4
)

install_packages "${INPUT_METHOD[@]}"

# Gaming
GAMING=(
  gamemode
  gamescope
  Mangohud
  vkBasalt
)

install_packages "${GAMING[@]}"

# Web browser
install_packages firefox

# Flatpak
install_packages flatpak

# Configure Flatpak
if command -v flatpak >/dev/null 2>&1; then
  echo "Setting up Flatpak..."
  if ! flatpak remotes | grep -q flathub; then
    execute flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  fi
fi

module_end
