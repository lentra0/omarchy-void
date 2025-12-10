#!/bin/bash

# Module: Desktop Tools
# Desktop environment tools and utilities

module_start "Desktop Tools Installation"

# Status bar and launcher
DESKTOP_BAR=(
  Waybar
  avizo
  fuzzel
  bluetuith
)

install_packages "${DESKTOP_BAR[@]}"

# Security and lockscreen
SECURITY_TOOLS=(
  swaylock
  dunst
)

install_packages "${SECURITY_TOOLS[@]}"

# Fonts
FONTS=(
  nerd-fonts
  font-awesome
  font-awesome5
  font-awesome6
)

install_packages "${FONTS[@]}"

# Screenshot and clipboard
SCREENSHOT_CLIPBOARD=(
  grim
  slurp
  swappy
  cliphist
  wl-clipboard
)

install_packages "${SCREENSHOT_CLIPBOARD[@]}"

# Input and audio control
INPUT_AUDIO=(
  playerctl
  pavucontrol
  swayidle
)

install_packages "${INPUT_AUDIO[@]}"

UTILS=(
  jq
  kvantum
)

install_packages "${UTILS[@]}"

module_end
