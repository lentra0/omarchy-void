#!/bin/bash

# Module: Theme Setup
# Sets up fonts, GTK themes, and creates theme links

module_start "Theme Setup"

# Create fonts directory and copy Omarchy font
echo "Setting up Omarchy font..."
mkdir_p ~/.local/share/fonts

OMARCHY_FONT="$HOME/.local/share/omarchy/default/omarchy.ttf"
if [ -f "$OMARCHY_FONT" ]; then
    echo "Copying Omarchy font..."
    execute cp "$OMARCHY_FONT" ~/.local/share/fonts/
    
    # Update font cache
    echo "Updating font cache..."
    execute fc-cache
else
    log_warning "Omarchy font not found at $OMARCHY_FONT"
fi

# Install GNOME themes
echo "Installing GNOME themes..."
install_packages gnome-themes-extra

# Configure GTK theme settings
echo "Configuring GTK theme..."
if command -v gsettings >/dev/null 2>&1; then
    execute gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark"
    execute gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
    log_success "GTK theme configured"
else
    log_warning "gsettings not found. GTK theme configuration skipped."
fi

# Setup theme links
echo "Setting up theme links..."
mkdir_p ~/.config/omarchy/themes

THEMES_SOURCE="$HOME/.local/share/omarchy/themes"
if [ -d "$THEMES_SOURCE" ]; then
    for theme_dir in "$THEMES_SOURCE"/*; do
        if [ -d "$theme_dir" ]; then
            theme_name=$(basename "$theme_dir")
            theme_link="$HOME/.config/omarchy/themes/$theme_name"
            execute ln -nfs "$theme_dir" "$theme_link"
        fi
    done
else
    log_warning "Source themes directory not found: $THEMES_SOURCE"
fi

# Set initial theme
echo "Setting initial theme..."
mkdir_p ~/.config/omarchy/current

# Link Tokyo Night theme
TOKYO_THEME="$HOME/.config/omarchy/themes/tokyo-night"
if [ -d "$TOKYO_THEME" ]; then
    execute ln -snf "$TOKYO_THEME" ~/.config/omarchy/current/theme
    log_success "Tokyo Night theme set as current"
else
    log_warning "Tokyo Night theme not found in ~/.config/omarchy/themes/"
fi

# Link background
if [ -d "$TOKYO_THEME" ] && [ -d "$TOKYO_THEME/backgrounds" ]; then
    BACKGROUND_FILE="$TOKYO_THEME/backgrounds/1-scenery-pink-lakeside-sunset-lake-landscape-scenic-panorama-7680x3215-144.png"
    if [ -f "$BACKGROUND_FILE" ]; then
        execute ln -snf "$BACKGROUND_FILE" ~/.config/omarchy/current/background
        log_success "Background image linked"
    else
        log_warning "Background file not found: $BACKGROUND_FILE"
    fi
fi

# Set specific app links for current theme
echo "Creating application theme links..."

# Neovim theme link
if [ -f "$TOKYO_THEME/neovim.lua" ]; then
    mkdir_p ~/.config/nvim/lua/plugins
    execute ln -snf "$TOKYO_THEME/neovim.lua" ~/.config/nvim/lua/plugins/theme.lua
    log_success "Neovim theme linked"
else
    log_warning "Neovim theme file not found: $TOKYO_THEME/neovim.lua"
fi

# Mako theme link
if [ -f "$TOKYO_THEME/mako.ini" ]; then
    mkdir_p ~/.config/mako
    execute ln -snf "$TOKYO_THEME/mako.ini" ~/.config/mako/config
    log_success "Mako theme linked"
else
    log_warning "Mako theme file not found: $TOKYO_THEME/mako.ini"
fi

# Install and configure LazyVim
echo "Installing and configuring LazyVim..."

# Remove existing Neovim config if exists
if [ -d ~/.config/nvim ]; then
    echo "Removing existing Neovim configuration..."
    execute rm -rf ~/.config/nvim
fi

# Clone LazyVim starter
echo "Cloning LazyVim starter..."
execute git clone https://github.com/LazyVim/starter ~/.config/nvim

# Check if custom config directory exists
CUSTOM_NVIM_CONFIG="$HOME/.local/share/omarchy/config/nvim"
if [ -d "$CUSTOM_NVIM_CONFIG" ]; then
    echo "Copying custom Neovim configuration..."
    execute cp -R "$CUSTOM_NVIM_CONFIG"/* ~/.config/nvim/
else
    log_warning "Custom Neovim config not found: $CUSTOM_NVIM_CONFIG"
fi

# Remove .git directory from LazyVim config
echo "Cleaning up LazyVim repository..."
if [ -d ~/.config/nvim/.git ]; then
    execute rm -rf ~/.config/nvim/.git
fi

# Disable relative line numbers
echo "Disabling relative line numbers..."
NVIM_OPTIONS_FILE="$HOME/.config/nvim/lua/config/options.lua"
if [ -f "$NVIM_OPTIONS_FILE" ]; then
    execute echo "vim.opt.relativenumber = false" >> "$NVIM_OPTIONS_FILE"
    log_success "Relative line numbers disabled"
else
    log_warning "Neovim options file not found: $NVIM_OPTIONS_FILE"
fi

# Check if Neovim is installed
if ! command -v nvim >/dev/null 2>&1; then
    log_warning "Neovim is not installed. Installing now..."
    install_packages neovim
fi

module_end