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

safe_umount() {
  local path="$1"
  local max_attempts=5
  local attempt=1

  while [ $attempt -le $max_attempts ]; do
    if mount | grep -q "$path"; then
      echo "Attempt $attempt to unmount $path"
      sudo umount -l "$path" 2>/dev/null && return 0
      sleep 1
    else
      return 0
    fi
    attempt=$((attempt + 1))
  done

  echo "Warning: Failed to unmount $path after $max_attempts attempts"
  return 1
}

read -p "Unmount chroot filesystems? [Y/n]: " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
  safe_umount "$ROOTFS/dev"
  safe_umount "$ROOTFS/sys"
  safe_umount "$ROOTFS/proc"
  echo "Chroot filesystems unmounted"
else
  echo "Chroot filesystems left mounted at $ROOTFS"
fi
