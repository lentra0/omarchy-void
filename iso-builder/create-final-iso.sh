#!/bin/bash
set -e

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 <base_iso> <chroot_directory> [output_directory]"
  exit 1
fi

BASE_ISO="$1"
CHROOT_DIR="$2"
OUTPUT_DIR="${3:-./output}"

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

WORKDIR="./work/iso-build"
ISO_MOUNT="$WORKDIR/iso-mount"
ISO_COPY="$WORKDIR/iso-copy"

echo "Creating work directories..."
sudo rm -rf "$WORKDIR"
mkdir -p "$ISO_MOUNT" "$ISO_COPY"

echo "Mounting base ISO..."
if sudo mount -o loop,ro "$BASE_ISO" "$ISO_MOUNT"; then
  echo "ISO mounted successfully"
else
  echo "Error: Failed to mount base ISO"
  exit 1
fi

echo "Copying ISO structure..."

COPY_SUCCESS=false

if command -v tar >/dev/null 2>&1; then
  echo "Using tar to copy ISO structure..."
  (cd "$ISO_MOUNT" && sudo tar cf - .) | (cd "$ISO_COPY" && sudo tar xpf -) 2>/dev/null && COPY_SUCCESS=true
fi

if [ "$COPY_SUCCESS" = false ] && command -v rsync >/dev/null 2>&1; then
  echo "Using rsync to copy ISO structure..."
  sudo rsync -aHAX "$ISO_MOUNT/" "$ISO_COPY/" 2>/dev/null && COPY_SUCCESS=true
fi

if [ "$COPY_SUCCESS" = false ]; then
  echo "Using cp to copy ISO structure (this may be slow)..."
  sudo cp -r "$ISO_MOUNT"/* "$ISO_COPY/" 2>/dev/null && COPY_SUCCESS=true
fi

if [ "$COPY_SUCCESS" = false ]; then
  echo "Error: Failed to copy ISO structure with any method"
  sudo umount "$ISO_MOUNT"
  exit 1
fi

sudo umount "$ISO_MOUNT"
echo "ISO structure copied successfully"

echo "Fixing permissions on boot files..."
sudo chmod -R a+r "$ISO_COPY" 2>/dev/null || true
if [ -f "$ISO_COPY/boot/initrd" ]; then
  sudo chmod +r "$ISO_COPY/boot/initrd"
fi
if [ -f "$ISO_COPY/boot/vmlinuz" ]; then
  sudo chmod +r "$ISO_COPY/boot/vmlinuz"
fi

SQUASHFS_DEST=""
if [ -d "$ISO_COPY/LiveOS" ]; then
  SQUASHFS_DEST="$ISO_COPY/LiveOS/squashfs.img"
elif [ -d "$ISO_COPY/live" ]; then
  SQUASHFS_DEST="$ISO_COPY/live/filesystem.squashfs"
else
  echo "Searching for squashfs in ISO copy..."
  SQUASHFS_PATH=$(find "$ISO_COPY" -name "*.img" -o -name "*.squashfs" -o -name "*squashfs*" | head -1)
  if [ -n "$SQUASHFS_PATH" ]; then
    SQUASHFS_DEST="$SQUASHFS_PATH"
    echo "Found squashfs at: $SQUASHFS_DEST"
  else
    echo "Error: Cannot find LiveOS or live directory in ISO"
    echo "Available directories:"
    ls -la "$ISO_COPY"
    exit 1
  fi
fi

mkdir -p "$(dirname "$SQUASHFS_DEST")"

echo "Creating new squashfs at: $SQUASHFS_DEST"
echo "Compressing chroot directory ($(sudo du -sh "$CHROOT_DIR" | cut -f1))..."

if [ -z "$(ls -A "$CHROOT_DIR" 2>/dev/null)" ]; then
  echo "Error: Chroot directory is empty!"
  exit 1
fi

sudo mksquashfs "$CHROOT_DIR" "$SQUASHFS_DEST" \
  -comp xz \
  -b 1M \
  -noappend \
  -no-recovery \
  -mem 8G \
  -Xdict-size 512K 2>&1 | tee "$WORKDIR/mksquashfs.log" || {
  echo "Error: Failed to create squashfs"
  echo "Log saved to: $WORKDIR/mksquashfs.log"
  echo "Try:"
  echo "  1. Check available space: df -h ."
  echo "  2. Clean up with: sudo rm -rf ./work"
  echo "  3. Try with less memory (edit -mem parameter)"
  exit 1
}

echo "Squashfs created: $(sudo du -h "$SQUASHFS_DEST" | cut -f1)"

echo "Setting correct permissions..."
sudo chown root:root "$SQUASHFS_DEST"
sudo chmod 644 "$SQUASHFS_DEST"

DATE=$(date +%Y%m%d)
ISO_NAME="omarchy-void-$DATE-x86_64.iso"
ISO_PATH="$OUTPUT_DIR/$ISO_NAME"

mkdir -p "$OUTPUT_DIR"

echo "Creating ISO: $ISO_PATH..."

echo "Checking boot files..."

if [ ! -f "$ISO_COPY/boot/isolinux/isolinux.bin" ]; then
  echo "Error: isolinux.bin not found at $ISO_COPY/boot/isolinux/isolinux.bin"
  echo "Available files in boot/isolinux:"
  ls -la "$ISO_COPY/boot/isolinux/" 2>/dev/null || echo "Directory not found"
  exit 1
fi

if [ ! -f "$ISO_COPY/boot/grub/efiboot.img" ]; then
  echo "Warning: efiboot.img not found at $ISO_COPY/boot/grub/efiboot.img"
  echo "Available files in boot/grub:"
  ls -la "$ISO_COPY/boot/grub/" 2>/dev/null || echo "Directory not found"
fi

if [ ! -f "$ISO_COPY/boot/isolinux/boot.cat" ]; then
  echo "Creating boot.cat..."
  sudo mkisofs -o /dev/null \
    -b "boot/isolinux/isolinux.bin" \
    -c "boot/isolinux/boot.cat" \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    "$ISO_COPY" 2>/dev/null || {
    echo "Warning: Failed to create boot.cat with mkisofs"
    echo "Creating empty boot.cat..."
    sudo touch "$ISO_COPY/boot/isolinux/boot.cat"
  }
fi

ISOHDPFX_PATH=""
for path in "/usr/lib/syslinux/isohdpfx.bin" "/usr/share/syslinux/isohdpfx.bin" "/usr/lib/ISOLINUX/isohdpfx.bin" "/usr/lib/syslinux/bios/isohdpfx.bin"; do
  if [ -f "$path" ]; then
    ISOHDPFX_PATH="$path"
    break
  fi
done

echo "Building ISO with xorriso..."

if [ -f "$ISO_COPY/boot/grub/efiboot.img" ] && [ -n "$ISOHDPFX_PATH" ]; then
  echo "Creating hybrid ISO with EFI support..."

  xorriso -as mkisofs \
    -volid "VOID_LIVE" \
    -isohybrid-mbr "$ISOHDPFX_PATH" \
    -c "boot/isolinux/boot.cat" \
    -b "boot/isolinux/isolinux.bin" \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -eltorito-alt-boot \
    -e "boot/grub/efiboot.img" \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    -o "$ISO_PATH" \
    "$ISO_COPY"
elif [ -f "$ISO_COPY/boot/grub/efiboot.img" ]; then
  echo "Creating ISO with EFI support (no hybrid MBR)..."

  xorriso -as mkisofs \
    -volid "VOID_LIVE" \
    -c "boot/isolinux/boot.cat" \
    -b "boot/isolinux/isolinux.bin" \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -eltorito-alt-boot \
    -e "boot/grub/efiboot.img" \
    -no-emul-boot \
    -o "$ISO_PATH" \
    "$ISO_COPY"
else
  echo "Creating ISO without EFI support..."

  xorriso -as mkisofs \
    -volid "VOID_LIVE" \
    -c "boot/isolinux/boot.cat" \
    -b "boot/isolinux/isolinux.bin" \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -o "$ISO_PATH" \
    "$ISO_COPY"
fi

if [ $? -eq 0 ] && [ -f "$ISO_PATH" ]; then
  echo ""
  echo "=== Final ISO created: $ISO_PATH ==="
  echo "Size: $(du -h "$ISO_PATH" | cut -f1)"

  if [ "$(id -u)" != "0" ]; then
    sudo chown $(id -u):$(id -g) "$ISO_PATH" 2>/dev/null || true
  fi

  echo "Creating checksum..."
  (cd "$OUTPUT_DIR" && sha256sum "$ISO_NAME" >"$ISO_NAME.sha256")

  sudo chmod -R u+w "$ISO_COPY" 2>/dev/null || true
  sudo rm -rf "$WORKDIR"
  echo "ISO successfully created!"
else
  echo "ERROR: Failed to create ISO"
  echo "Work directory preserved at: $WORKDIR"
  echo "Last 20 lines of possible error log:"
  tail -20 "$WORKDIR/mksquashfs.log" 2>/dev/null || echo "No log file found"
  exit 1
fi
