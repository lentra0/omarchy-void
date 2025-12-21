#!/bin/bash
set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <path_to_mounted_ext3fs>"
  exit 1
fi

ROOTFS="$1"

if ! mount | grep -q "$ROOTFS"; then
  echo "Error: $ROOTFS is not mounted"
  exit 1
fi

sudo mount -t proc proc "$ROOTFS/proc"
sudo mount -t sysfs sys "$ROOTFS/sys"
sudo mount -o bind /dev "$ROOTFS/dev"

echo "nameserver 8.8.8.8" | sudo tee "$ROOTFS/etc/resolv.conf" >/dev/null
echo "nameserver 1.1.1.1" | sudo tee -a "$ROOTFS/etc/resolv.conf" >/dev/null

SETUP_SCRIPT="./chroot-user-setup.sh"
if [ -f "$SETUP_SCRIPT" ]; then
  echo "Copying setup script to chroot..."
  sudo cp "$SETUP_SCRIPT" "$ROOTFS/tmp/chroot-setup.sh"
  sudo chmod +x "$ROOTFS/tmp/chroot-setup.sh"
  echo "Setup script available at: /tmp/chroot-setup.sh"
else
  echo "Warning: Setup script not found: $SETUP_SCRIPT"
fi

echo "Entering chroot at $ROOTFS"
echo ""
echo "Available commands:"
echo "  /tmp/chroot-setup.sh  - Run setup script (if available)"
echo "  git clone https://github.com/lentra0/omarchy-void ~/.local/share/omarchy"
echo "  cd ~/.local/share/omarchy && ./install.sh"
echo ""
echo "Type 'exit' when finished, then the script will clean up mounts."
echo ""

sudo chroot "$ROOTFS" /bin/bash

echo ""
echo "Chroot session ended"
read -p "Unmount chroot filesystems? [Y/n]: " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
  sudo umount -l "$ROOTFS/dev" 2>/dev/null || true
  sudo umount -l "$ROOTFS/sys" 2>/dev/null || true
  sudo umount -l "$ROOTFS/proc" 2>/dev/null || true
  echo "Chroot filesystems unmounted"
else
  echo "Chroot filesystems left mounted at $ROOTFS"
fi
