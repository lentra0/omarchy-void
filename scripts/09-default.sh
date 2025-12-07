#!/bin/bash

# Module: Default Configuration Files
# Copies default configuration files to user home directory

module_start "Default Configuration Files"

# Function to copy configuration file with backup
copy_config() {
    local source_file="$1"
    local target_file="$2"
    local file_name=$(basename "$source_file")
    
    echo "Processing $file_name..."
    
    # Check if source file exists
    if [ ! -f "$source_file" ]; then
        log_warning "Source file not found: $source_file"
        return 1
    fi
    
    # Check if target file already exists
    if [ -f "$target_file" ] || [ -L "$target_file" ]; then
        # Create backup with timestamp
        local backup_file="${target_file}.backup.$(date +%Y%m%d_%H%M%S)"
        echo "Backing up existing $file_name to $backup_file"
        execute cp "$target_file" "$backup_file"
    fi
    
    # Copy the file
    echo "Copying $file_name to $target_file"
    execute cp "$source_file" "$target_file"
    
    # Set proper permissions
    execute chmod 644 "$target_file"
    
    log_success "$file_name copied successfully"
}

# Define source and target paths
DEFAULT_DIR="$HOME/.local/share/omarchy/default"

# 1. Copy .zshrc if it exists in default directory
ZSH_SOURCE="$DEFAULT_DIR/zshrc"
ZSH_TARGET="$HOME/.zshrc"

if [ -f "$ZSH_SOURCE" ]; then
    copy_config "$ZSH_SOURCE" "$ZSH_TARGET"
else
    log_warning "Default .zshrc not found at: $ZSH_SOURCE"
    log_info "You can create it later and copy manually"
fi

# 2. Copy .bash_profile if it exists in default directory
BASH_SOURCE="$DEFAULT_DIR/bash_profile"
BASH_TARGET="$HOME/.bash_profile"

if [ -f "$BASH_SOURCE" ]; then
    copy_config "$BASH_SOURCE" "$BASH_TARGET"
else
    log_warning "Default .bash_profile not found at: $BASH_SOURCE"
    log_info "You can create it later and copy manually"
fi

module_end