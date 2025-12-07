#!/bin/bash

# Module: Multimedia
# Audio, video, and wallpaper tools

module_start "Multimedia Installation"

# Audio
AUDIO_PACKAGES=(
  pipewire
  wireplumber
)

install_packages "${AUDIO_PACKAGES[@]}"

# Video and codecs
VIDEO_PACKAGES=(
  ffmpeg
)

install_packages "${VIDEO_PACKAGES[@]}"

# Wallpaper tools
WALLPAPER_TOOLS=(
  swaybg
  mpvpaper
  swww
)

install_packages "${WALLPAPER_TOOLS[@]}"

# Notifications
install_packages libnotify

module_end

