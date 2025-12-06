#!/bin/bash

# Module: Graphics
# Vulkan, OpenGL, graphics libraries

module_start "Graphics Installation"

# Vulkan and graphics libraries
GRAPHICS_PACKAGES=(
    Vulkan-Headers
    Vulkan-Tools
    Vulkan-ValidationLayers-32bit
    vulkan-loader
    vulkan-loader-32bit
    libspa-vulkan
    libspa-vulkan-32bit
    libglapi
)

install_packages "${GRAPHICS_PACKAGES[@]}"

module_end