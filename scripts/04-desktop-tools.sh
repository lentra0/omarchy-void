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
  #nerd-fonts
  nerd-fonts-symbols-ttf
  nerd-fonts-otf
  font-awesome
  font-awesome5
  font-awesome6
)

install_packages "${FONTS[@]}"

# Screenshot and clipboard
SCREENSHOT_CLIPBOARD=(
  grim
  slurp
  satty
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
  powertop
  jq
  kvantum
)

install_packages "${UTILS[@]}"

# Install Gazelle TUI - NetworkManager TUI
echo "Installing Gazelle TUI (NetworkManager TUI)..."

# Install dependencies
GAZELLE_DEPS=(
  python3
  python3-textual
  python3-dbus
  python3-tomli
  NetworkManager-openvpn
  wireguard-tools
  ModemManager # For WWAN/cellular support
)

install_packages "${GAZELLE_DEPS[@]}"

# Check if curl is installed
if ! command -v curl >/dev/null 2>&1; then
  install_packages curl
fi

# Download and install Gazelle TUI
GAZELLE_VERSION="1.8.2"
GAZELLE_URL="https://github.com/Zeus-Deus/gazelle-tui/archive/v${GAZELLE_VERSION}.tar.gz"
GAZELLE_TAR="/tmp/gazelle-tui-${GAZELLE_VERSION}.tar.gz"
GAZELLE_DIR="/tmp/gazelle-tui-${GAZELLE_VERSION}"

# Download Gazelle TUI
echo "Downloading Gazelle TUI v${GAZELLE_VERSION}..."
execute curl -L -o "$GAZELLE_TAR" "$GAZELLE_URL"

# Extract
echo "Extracting Gazelle TUI..."
execute tar -xzf "$GAZELLE_TAR" -C /tmp

# Install Gazelle TUI
echo "Installing Gazelle TUI files..."
execute sudo mkdir -p /usr/share/gazelle-tui
execute sudo cp "$GAZELLE_DIR/network.py" /usr/share/gazelle-tui/
execute sudo cp "$GAZELLE_DIR/app.py" /usr/share/gazelle-tui/

# Create wrapper script
echo "Creating Gazelle TUI wrapper script..."
execute sudo tee /usr/bin/gazelle >/dev/null <<'EOF'
#!/usr/bin/bash
# Gazelle TUI wrapper - Force system Python, not conda
exec /usr/bin/python3 -c "
import sys
sys.path.insert(0, '/usr/share/gazelle-tui')
from app import Gazelle
app = Gazelle()
app.run()
"
EOF

execute sudo chmod +x /usr/bin/gazelle

# Install documentation
echo "Installing Gazelle TUI documentation..."
execute sudo mkdir -p /usr/share/doc/gazelle-tui
execute sudo cp "$GAZELLE_DIR/README.md" /usr/share/doc/gazelle-tui/

# Install license if exists
if [ -f "$GAZELLE_DIR/LICENSE" ]; then
  execute sudo mkdir -p /usr/share/licenses/gazelle-tui
  execute sudo cp "$GAZELLE_DIR/LICENSE" /usr/share/licenses/gazelle-tui/
fi

# Cleanup
echo "Cleaning up temporary files..."
execute sudo rm -rf "$GAZELLE_TAR" "$GAZELLE_DIR"

# Add user to network group if not already
echo "Adding user to network group..."
if ! groups "$USER" | grep -q '\bnetwork\b'; then
  execute sudo usermod -aG network "$USER"
  log_success "User added to network group (re-login required)"
else
  echo "User already in network group"
fi

# Enable NetworkManager service
echo "Enabling NetworkManager service..."
if [ ! -h /var/service/NetworkManager ]; then
  execute sudo ln -s /etc/sv/NetworkManager /var/service/
  log_success "NetworkManager service enabled"
else
  echo "NetworkManager service already enabled"
fi

log_success "Gazelle TUI installed successfully"

module_end
