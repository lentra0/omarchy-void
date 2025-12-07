#!/bin/bash

# Main installer script
# Simply sources all modules in order

set -Euo pipefail

export PATH="$HOME/.local/share/omarchy/bin:$PATH"

# Load error handler
source scripts/error.sh

# Source all modules in order
source scripts/01-hyprland-core.sh
source scripts/02-graphics.sh
source scripts/03-system-services.sh
source scripts/04-desktop-tools.sh
source scripts/05-shell.sh
source scripts/06-utilities.sh
source scripts/07-multimedia.sh
source scripts/08-theme.sh
source scripts/09-default.sh
source scripts/10-misc.sh

echo -e "${GREEN}${BOLD}========================================${NC}"
echo -e "${GREEN}${BOLD}    All modules installed successfully!${NC}"
echo -e "${GREEN}${BOLD}========================================${NC}"

# Final instructions
echo -e "${YELLOW}${BOLD}Important Notes:${NC}"
echo "1. PATH changes require a reboot to take effect"
echo "2. Services have been enabled and started"
echo "3. Default shell has been changed to Zsh"
echo "4. All packages are installed and configured"
echo ""

# Countdown and reboot
echo -e "${RED}${BOLD}System will reboot in 5 seconds...${NC}"
echo -e "${YELLOW}Press Ctrl+C to cancel the reboot${NC}"
echo ""

for i in {5..1}; do
  echo -ne "${RED}Rebooting in $i seconds...${NC}\r"
  sleep 1
done

echo -e "\n${GREEN}${BOLD}Rebooting system now...${NC}"

execute loginctl reboot
