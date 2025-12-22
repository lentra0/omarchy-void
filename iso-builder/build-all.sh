#!/bin/bash
set -e

echo "=== Void Linux Custom ISO Builder ==="
echo "Script execution started: $(date)"

WORKDIR="${WORKDIR:-./work}"
OUTPUTDIR="${OUTPUTDIR:-./output}"

unmount_all() {
  echo "Unmounting any leftover mounts..."

  for mount_point in $(mount | grep "$WORKDIR" | awk '{print $3}' | sort -r); do
    echo "Unmounting $mount_point"
    sudo umount -l "$mount_point" 2>/dev/null || true
  done

  sleep 2

  if mount | grep -q "$WORKDIR"; then
    echo "Warning: Some mounts in $WORKDIR are still active"
    mount | grep "$WORKDIR"
  fi
}

echo "Cleaning up any previous mounts..."
unmount_all

if [ -d "$WORKDIR" ]; then
  echo "Cleaning previous work directory..."
  sudo rm -rf "$WORKDIR/iso-mount" "$WORKDIR/rootfs" "$WORKDIR/temp" "$WORKDIR/iso-build"
fi

mkdir -p "$WORKDIR" "$OUTPUTDIR"

check_deps() {
  echo "Checking dependencies..."

  local deps=("git" "sudo" "curl" "wget" "xorriso" "squashfs-tools" "tar" "rsync")
  local missing=()

  for dep in "${deps[@]}"; do
    if ! command -v $dep >/dev/null 2>&1; then
      missing+=("$dep")
    fi
  done

  if [ ${#missing[@]} -gt 0 ]; then
    echo "Installing missing dependencies: ${missing[*]}"
    sudo xbps-install -S "${missing[@]}"
  fi
}

error_handler() {
  echo ""
  echo "=== ERROR ==="
  echo "Line: $1"
  echo "Command: $2"
  echo "Code: $3"
  echo ""
  echo "Cleaning up mounts..."
  unmount_all
  exit 1
}

trap 'error_handler ${LINENO} "$BASH_COMMAND" $?' ERR

check_deps

echo ""
echo "=== STEP 1: Building base ISO ==="
./build-base-iso.sh

BASE_ISO=$(find "$WORKDIR/base" -name "void-base-x86_64-*.iso" -type f | head -1)
if [ -z "$BASE_ISO" ]; then
  echo "Error: Could not find base ISO"
  exit 1
fi

echo "Base ISO found: $BASE_ISO"

echo ""
echo "=== STEP 2: Preparing chroot environment ==="

ROOTFS="$WORKDIR/rootfs"
ISO_MOUNT="$WORKDIR/iso-mount"
TEMP_DIR="$WORKDIR/temp"

echo "Creating directories..."
sudo rm -rf "$ROOTFS" "$ISO_MOUNT" "$TEMP_DIR"
mkdir -p "$ROOTFS" "$ISO_MOUNT" "$TEMP_DIR"

echo "Mounting ISO at $ISO_MOUNT..."
if sudo mount -o loop,ro "$BASE_ISO" "$ISO_MOUNT"; then
  echo "ISO mounted successfully"
else
  echo "Error: Failed to mount ISO"
  exit 1
fi

SQUASHFS_PATH=$(find "$ISO_MOUNT" -name "*.img" -o -name "*.squashfs" | head -1)
if [ -z "$SQUASHFS_PATH" ]; then
  echo "Error: Could not find squashfs in ISO"
  sudo umount "$ISO_MOUNT"
  exit 1
fi

echo "Found squashfs: $SQUASHFS_PATH"
echo "Extracting to $TEMP_DIR..."

if sudo unsquashfs -f -d "$TEMP_DIR" "$SQUASHFS_PATH"; then
  echo "Squashfs extracted successfully"
else
  echo "Error: Failed to extract squashfs"
  sudo umount "$ISO_MOUNT"
  exit 1
fi

sudo umount "$ISO_MOUNT"

EXT3_IMG="$TEMP_DIR/LiveOS/ext3fs.img"
if [ ! -f "$EXT3_IMG" ]; then
  echo "Error: ext3fs.img not found at $EXT3_IMG"
  exit 1
fi

echo "Expanding ext3fs.img..."

CURRENT_SIZE=$(sudo stat -c%s "$EXT3_IMG")
DESIRED_SIZE=$((10 * 1024 * 1024 * 1024))

if [ "$CURRENT_SIZE" -lt "$DESIRED_SIZE" ]; then
  echo "Current size: $CURRENT_SIZE bytes ($(($CURRENT_SIZE / 1024 / 1024)) MB)"
  echo "Expanding to: $DESIRED_SIZE bytes"

  ADD_SIZE_MB=$((($DESIRED_SIZE - $CURRENT_SIZE) / 1024 / 1024))
  echo "Adding $ADD_SIZE_MB MB..."

  sudo sh -c "dd if=/dev/zero bs=1M count=$ADD_SIZE_MB >> \"$EXT3_IMG\""

  sudo e2fsck -f -y "$EXT3_IMG" 2>/dev/null || true
  sudo resize2fs "$EXT3_IMG" 10G

  echo "New size: $(sudo stat -c%s "$EXT3_IMG") bytes"
else
  echo "Image is already $CURRENT_SIZE bytes"
fi

echo "Mounting ext3fs.img to $ROOTFS..."
if sudo mount -o loop "$EXT3_IMG" "$ROOTFS"; then
  echo "ext3fs.img mounted successfully"
else
  echo "Error: Failed to mount ext3fs.img"
  exit 1
fi

echo "Chroot environment prepared successfully"

echo ""
echo "=== STEP 3: Configuring system in chroot ==="
./chroot-postinstall.sh "$ROOTFS"

echo ""
echo "=== STEP 4: Creating final ISO ==="
./create-final-iso.sh "$BASE_ISO" "$ROOTFS" "$OUTPUTDIR"

echo ""
echo "=== BUILD COMPLETE ==="
echo "Base ISO:    $BASE_ISO"
echo "Final ISO:   $OUTPUTDIR/omarcchy-void-$(date +%Y%m%d)-x86_64.iso"
echo "Work dir:    $WORKDIR"
echo "Output dir:  $OUTPUTDIR"
echo ""
echo "Script execution finished: $(date)"
