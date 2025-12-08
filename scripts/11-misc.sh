#!/bin/bash

# Module: Miscellaneous System Configuration
# Sets up PATH and installs icon theme

module_start "Miscellaneous System Configuration"

# 1. Add user's bin directory to system PATH in /etc/environment
echo "Configuring system PATH..."

# Get current username
CURRENT_USER="$USER"
USER_BIN_PATH="/home/$CURRENT_USER/.local/share/omarchy/bin"

# Create the directory if it doesn't exist
if [ ! -d "$USER_BIN_PATH" ]; then
  echo "Creating user bin directory..."
  execute mkdir -p "$USER_BIN_PATH"
fi

# The new PATH string to add
NEW_PATH="PATH=/home/$CURRENT_USER/.local/share/omarchy/bin:/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/sbin:/bin"

# Check if PATH is already configured in /etc/environment
if grep -q "^PATH=" /etc/environment; then
  echo "PATH already exists in /etc/environment"

  # Check if our custom path is already there
  if grep -q "^PATH=.*.local/share/omarchy/bin.*" /etc/environment; then
    echo "Custom bin directory already in PATH"
  else
    # Backup original file
    echo "Backing up /etc/environment..."
    execute sudo cp /etc/environment /etc/environment.backup.$(date +%Y%m%d_%H%M%S)

    # Update existing PATH line
    echo "Updating PATH in /etc/environment..."
    execute sudo sed -i "s|^PATH=.*|$NEW_PATH|" /etc/environment
    echo "PATH updated with custom bin directory"
  fi
else
  # Backup original file
  echo "Backing up /etc/environment..."
  execute sudo cp /etc/environment /etc/environment.backup.$(date +%Y%m%d_%H%M%S)

  # Add new PATH line
  echo "Adding PATH to /etc/environment..."
  execute echo "$NEW_PATH" | sudo tee -a /etc/environment
  echo "Custom PATH added to /etc/environment"
fi

# Show the current PATH from /etc/environment
echo "Current system PATH configuration:"
grep "^PATH=" /etc/environment || echo "No PATH found in /etc/environment"

# 2. Clone and install MacTahoe icon theme (only cursors)
echo ""
echo "Installing MacTahoe icon theme (cursors only)..."

# Check if git is installed
if ! command -v git >/dev/null 2>&1; then
  echo "Git is not installed. Installing git..."
  install_packages git
fi

# Create temporary directory for theme
TEMP_THEME_DIR="/tmp/MacTahoe-icon-theme-$(date +%s)"
echo "Creating temporary directory: $TEMP_THEME_DIR"
execute mkdir -p "$TEMP_THEME_DIR"

# Clone the theme repository
echo "Cloning MacTahoe cursor theme..."
execute git clone https://github.com/vinceliuice/MacTahoe-icon-theme.git "$TEMP_THEME_DIR"

# Check if clone was successful
if [ -d "$TEMP_THEME_DIR" ]; then
  echo "Theme cloned successfully"

  # Look for cursors install script
  CURSORS_INSTALL="$TEMP_THEME_DIR/cursors/install.sh"

  if [ -f "$CURSORS_INSTALL" ]; then
    echo "Found cursors install script: $CURSORS_INSTALL"

    # Make the script executable
    execute chmod +x "$CURSORS_INSTALL"

    # Run the install script
    echo "Running cursors install script..."
    execute sudo "$CURSORS_INSTALL"

    echo "MacTahoe cursors installed successfully"
  else
    log_warning "Cursors install script not found: $CURSORS_INSTALL"

    # Try root install script as fallback
    ROOT_INSTALL="$TEMP_THEME_DIR/install.sh"
    if [ -f "$ROOT_INSTALL" ]; then
      echo "Found main install script, running it..."
      execute chmod +x "$ROOT_INSTALL"
      execute sudo "$ROOT_INSTALL"
    else
      log_error "No install script found in theme directory"
    fi
  fi
else
  log_error "Failed to clone theme repository"
fi

# Clean up temporary directory
echo "Cleaning up temporary files..."
if [ -d "$TEMP_THEME_DIR" ]; then
  execute rm -rf "$TEMP_THEME_DIR"
  echo "Temporary directory removed"
fi

# Final notes
echo ""
echo -e "${GREEN}Configuration completed!${NC}"
echo ""
echo -e "${YELLOW}Note:${NC} PATH changed in /etc/environment requires a reboot to take effect"

module_end

