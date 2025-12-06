#!/bin/bash

# Module: Shell and Terminal
# Shell, terminal, and development tools

module_start "Shell and Terminal Installation"

# Shell
SHELL_PACKAGES=(
    zsh
    zsh-autosuggestions
    zsh-history-substring-search
    zsh-syntax-highlighting
    fzf
)

install_packages "${SHELL_PACKAGES[@]}"

# Clone fzf-tab plugin
echo "Installing fzf-tab plugin..."
if [ ! -d "/usr/share/zsh/plugins/fzf-tab-git" ]; then
    execute sudo git clone https://github.com/Aloxaf/fzf-tab /usr/share/zsh/plugins/fzf-tab-git
else
    echo "fzf-tab already installed, skipping..."
fi

# Terminal
TERMINAL_PACKAGES=(
    alacritty
    tmux
)

install_packages "${TERMINAL_PACKAGES[@]}"

# Change shell to Zsh
echo "Changing default shell to Zsh..."
if command -v zsh >/dev/null 2>&1; then
    execute sudo chsh -s $(command -v zsh) $USER
    echo "Default shell changed to Zsh"
else
    echo "Zsh not found, skipping shell change"
fi

module_end