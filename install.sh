#!/bin/bash

# Main installer script
# Simply sources all modules in order

set -Euo pipefail

export PATH="$HOME/.local/share/omarchy/bin:$PATH"

WORKDIR=~/.local/share/omarchy

# Load error handler
source ${WORKDIR}/scripts/error.sh

install_packages bc

# Source all modules in order
source ${WORKDIR}/scripts/01-hyprland-core.sh
source ${WORKDIR}/scripts/02-graphics.sh
source ${WORKDIR}/scripts/03-system-services.sh
source ${WORKDIR}/scripts/04-desktop-tools.sh
source ${WORKDIR}/scripts/05-shell.sh
source ${WORKDIR}/scripts/06-utilities.sh
source ${WORKDIR}/scripts/07-multimedia.sh
source ${WORKDIR}/scripts/08-theme.sh
source ${WORKDIR}/scripts/09-config.sh
source ${WORKDIR}/scripts/10-default.sh
source ${WORKDIR}/scripts/11-misc.sh

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
for i in {10..1}; do
  echo -ne "${RED}Rebooting in $i seconds...${NC}\r"
  sleep 1
done

echo -e "\n${GREEN}${BOLD}Rebooting system now...${NC}"

sudo reboot
