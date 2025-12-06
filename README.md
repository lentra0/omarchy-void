# omarchy-void

A complete Void Linux setup system based on the original [**Omarchy**](https://github.com/basecamp/omarchy) configuration, adapted for Void Linux with Hyprland.

## Features

- **Complete Hyprland Setup** - Full Wayland compositor with all necessary dependencies
- **System Configuration** - Optimized for Void Linux with runit services
- **Development Environment** - Modern tools and editors pre-configured
- **Theme Management** - Easy theme switching with automatic application configuration
- **Zsh Setup** - Modern shell with plugins and fzf integration
- **LazyVim** - Pre-configured Neovim setup based on LazyVim starter

## Installation

```bash
# Clone the repository
git clone https://github.com/lentra0/omarchy-void ~/.local/share/omarchy

# Run the installer
~/.local/share/omarchy/install.sh
```

The installer will automatically:
1. Install all necessary packages from Void Linux repositories
2. Configure system services and user groups
3. Set up Hyprland and Wayland environment
4. Install and configure development tools
5. Set up themes and cursor configuration
6. Reboot the system for all changes to take effect

## Module Structure

The installation is divided into logical modules:

| Module | Description |
|--------|-------------|
| `01-hyprland-core.sh` | Core Hyprland and Wayland packages |
| `02-graphics.sh` | Graphics drivers and Vulkan support |
| `03-system-services.sh` | System services, networking, authentication |
| `04-desktop-tools.sh` | Desktop environment tools and utilities |
| `05-shell.sh` | Zsh shell with plugins and configuration |
| `06-utilities.sh` | Various utilities and applications |
| `07-multimedia.sh` | Audio, video, and wallpaper tools |
| `08-theme.sh` | Theme configuration and LazyVim setup |
| `09-misc.sh` | System PATH configuration and cursor theme |

## Configuration

### Services Enabled

The following runit services are automatically enabled:

- `dbus` - Message bus system
- `crond` - Cron daemon for scheduled tasks
- `seatd` - Seat management daemon
- `elogind` - Login manager
- `polkitd` - PolicyKit authorization
- `bluetoothd` - Bluetooth service

## Credits & Acknowledgments

This project builds upon the work of several amazing open-source projects:

### **Original Omarchy**
Massive thanks to the original [**Omarchy**](https://github.com/basecamp/omarchy) project by Basecamp. This configuration is a port of their excellent Arch Linux setup to Void Linux.

### **Hyprland for Void Linux**
Special thanks to [**Makrennel**](https://github.com/Makrennel) for maintaining the Hyprland repository for Void Linux.

### **Cursor Theme**
Beautiful cursor theme provided by [**vinceliuice**](https://github.com/vinceliuice) with the MacTahoe icon theme.

## Troubleshooting

- Installation log: `~/.cache/omarchy/logs/`

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Disclaimer

This setup is tailored for my personal workflow and may not suit everyone's needs. Use at your own risk and always review scripts before running them on your system.
