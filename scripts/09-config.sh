#!/bin/bash

# Module: Configuration Setup
# Copies configuration files from repository to ~/.config

module_start "Configuration Setup"

# Copy configuration files from WORKDIR/config to ~/.config
echo "Copying configuration files..."
if [ -d "${WORKDIR}/config" ]; then
  echo "Found config directory in ${WORKDIR}/config, copying contents..."

  # Create target directory
  mkdir_p ~/.config

  # Copy all files and directories from WORKDIR/config to ~/.config
  for item in "${WORKDIR}"/config/*; do
    if [ -e "$item" ]; then
      item_name=$(basename "$item")
      echo "Copying $item_name..."
      execute cp -R "$item" ~/.config/
    fi
  done

  log_success "Configuration files copied"

  # Show what was copied (for debugging)
  echo "Copied items in ~/.config:"
  ls -la ~/.config/ | head -20

else
  log_warning "Config directory not found at ${WORKDIR}/config"
  echo "Checking ${WORKDIR}:"
  ls -la "${WORKDIR}"/
fi

module_end
