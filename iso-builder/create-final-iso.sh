#!/bin/bash
set -e

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 <base_iso> <chroot_directory> [output_directory]"
  exit 1
fi

BASE_ISO="$1"
CHROOT_DIR="$2"
OUTPUT_DIR="${3:-.}"

if [ ! -f "$BASE_ISO" ]; then
  echo "Error: Base ISO not found: $BASE_ISO"
  exit 1
fi

if [ ! -d "$CHROOT_DIR" ]; then
  echo "Error: Chroot directory not found: $CHROOT_DIR"
  exit 1
fi

for cmd in unsquashfs mksquashfs xorriso; do
  if ! command -v $cmd >/dev/null 2>&1; then
    echo "Installing $cmd..."
    sudo xbps-install -S squashfs-tools xorriso
    break
  fi
done

echo "=== Creating final ISO ==="

WORKDIR=$(mktemp -d)
echo "Work directory: $WORKDIR"

echo "Mounting base ISO..."
ISO_MOUNT="$WORKDIR/iso-mount"
mkdir -p "$ISO_MOUNT"
sudo mount -o loop,ro "$BASE_ISO" "$ISO_MOUNT" 2>/dev/null || {
  echo "Error: Failed to mount base ISO"
  exit 1
}

echo "Copying ISO structure..."
ISO_COPY="$WORKDIR/iso-copy"
mkdir -p "$ISO_COPY"
cp -a "$ISO_MOUNT/." "$ISO_COPY/" 2>/dev/null || {
  echo "Error: Failed to copy ISO structure"
  sudo umount "$ISO_MOUNT"
  exit 1
}

sudo umount "$ISO_MOUNT"

SQUASHFS_DEST=""
if [ -d "$ISO_COPY/LiveOS" ]; then
  SQUASHFS_DEST="$ISO_COPY/LiveOS/squashfs.img"
elif [ -d "$ISO_COPY/live" ]; then
  SQUASHFS_DEST="$ISO_COPY/live/filesystem.squashfs"
else
  echo "Error: Cannot find LiveOS or live directory in ISO"
  exit 1
fi

mkdir -p "$(dirname "$SQUASHFS_DEST")"

echo "Creating new squashfs at: $SQUASHFS_DEST"
sudo mksquashfs "$CHROOT_DIR" "$SQUASHFS_DEST" \
  -comp xz \
  -b 1M \
  -noappend \
  -no-recovery \
  -Xdict-size 1M 2>/dev/null || {
  echo "Error: Failed to create squashfs"
  exit 1
}

echo "Setting correct permissions..."
sudo chown root:root "$SQUASHFS_DEST"
sudo chmod 644 "$SQUASHFS_DEST"

DATE=$(date +%Y%m%d)
ISO_NAME="omarcchy-void-$DATE-x86_64.iso"
ISO_PATH="$OUTPUT_DIR/$ISO_NAME"

echo "Creating ISO: $ISO_PATH..."

ISOHDPFX_PATH=""
if [ -f "/usr/lib/ISOLINUX/isohdpfx.bin" ]; then
  ISOHDPFX_PATH="/usr/lib/ISOLINUX/isohdpfx.bin"
elif [ -f "/usr/share/syslinux/isohdpfx.bin" ]; then
  ISOHDPFX_PATH="/usr/share/syslinux/isohdpfx.bin"
else
  echo "Warning: isohdpfx.bin not found, trying without it"
fi

XORRISO_CMD="xorriso -as mkisofs \
  -volid 'VOID_LIVE' \
  -isohybrid-mbr ${ISOHDPFX_PATH:+-isohybrid-mbr "$ISOHDPFX_PATH"} \
  -c boot.cat \
  -b isolinux.bin \
  -no-emul-boot \
  -boot-load-size 4 \
  -boot-info-table \
  -eltorito-alt-boot \
  -e boot/grub/efi.img \
  -no-emul-boot \
  -isohybrid-gpt-basdat \
  -o '$ISO_PATH' \
  '$ISO_COPY'"

echo "Executing: $XORRISO_CMD"
eval "$XORRISO_CMD" || {
  echo "Error: Failed to create ISO"
  exit 1
}

#sudo rm -rf "$WORKDIR"

echo "=== Final ISO created: $ISO_PATH ==="
echo "Size: $(du -h "$ISO_PATH" | cut -f1)"
