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
sudo rsync -aHAX "$ISO_MOUNT/" "$ISO_COPY/" 2>/dev/null || {
  echo "Error: Failed to copy ISO structure with rsync"
  sudo umount "$ISO_MOUNT"
  exit 1
}

sudo umount "$ISO_MOUNT"

echo "Fixing permissions on boot files..."
sudo chmod -R a+r "$ISO_COPY" 2>/dev/null || true
sudo chmod +r "$ISO_COPY/boot/initrd" 2>/dev/null || true
sudo chmod +r "$ISO_COPY/boot/vmlinuz" 2>/dev/null || true

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
  -mem 4G \
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

mkdir -p "$OUTPUTDIR"

echo "Creating ISO: $ISO_PATH..."

echo "Checking boot files..."
if [ ! -f "$ISO_COPY/boot/initrd" ]; then
  echo "Warning: initrd not found at $ISO_COPY/boot/initrd"
  ALT_INITRD=$(find "$ISO_COPY" -name "initrd" -o -name "initrd.img" -type f | head -1)
  if [ -n "$ALT_INITRD" ]; then
    echo "Found initrd at: $ALT_INITRD"
  else
    echo "Error: Cannot find initrd file"
    exit 1
  fi
fi

ISOLINUX_BIN=""
for path in "$ISO_COPY/isolinux/isolinux.bin" "$ISO_COPY/boot/isolinux/isolinux.bin" "$ISO_COPY/boot/isolinux.bin"; do
  if [ -f "$path" ]; then
    ISOLINUX_BIN="$path"
    break
  fi
done

if [ -z "$ISOLINUX_BIN" ]; then
  echo "Warning: isolinux.bin not found at standard locations"
  ISOLINUX_BIN=$(find "$ISO_COPY" -name "isolinux.bin" -type f | head -1)
  if [ -n "$ISOLINUX_BIN" ]; then
    echo "Found isolinux.bin at: $ISOLINUX_BIN"
  else
    echo "Error: Cannot find isolinux.bin"
    exit 1
  fi
fi

EFI_IMG=""
for path in "$ISO_COPY/boot/grub/efi.img" "$ISO_COPY/efi.img" "$ISO_COPY/boot/efi.img"; do
  if [ -f "$path" ]; then
    EFI_IMG="$path"
    break
  fi
done

if [ -z "$EFI_IMG" ]; then
  echo "Warning: efi.img not found at standard locations"
  EFI_IMG=$(find "$ISO_COPY" -name "efi.img" -type f | head -1)
  if [ -n "$EFI_IMG" ]; then
    echo "Found efi.img at: $EFI_IMG"
  else
    echo "Note: efi.img not found, creating ISO without EFI support"
  fi
fi

if [ ! -f "$ISO_COPY/isolinux/boot.cat" ]; then
  echo "Creating boot.cat..."
  sudo mkisofs -o /dev/null -b isolinux/isolinux.bin -no-emul-boot -boot-load-size 4 -boot-info-table "$ISO_COPY" 2>/dev/null || true
fi

ISOHDPFX_PATH=""
for path in "/usr/lib/syslinux/isohdpfx.bin" "/usr/share/syslinux/isohdpfx.bin" "/usr/lib/ISOLINUX/isohdpfx.bin"; do
  if [ -f "$path" ]; then
    ISOHDPFX_PATH="$path"
    break
  fi
done

echo "Building ISO with xorriso..."

REL_ISOLINUX_BIN="${ISOLINUX_BIN#$ISO_COPY/}"
REL_EFI_IMG="${EFI_IMG#$ISO_COPY/}" 2>/dev/null || true

if [ -n "$EFI_IMG" ]; then
  if [ -n "$ISOHDPFX_PATH" ]; then
    echo "Using isohdpfx.bin from: $ISOHDPFX_PATH"
    xorriso -as mkisofs \
      -volid "VOID_LIVE" \
      -isohybrid-mbr "$ISOHDPFX_PATH" \
      -c isolinux/boot.cat \
      -b "$REL_ISOLINUX_BIN" \
      -no-emul-boot \
      -boot-load-size 4 \
      -boot-info-table \
      -eltorito-alt-boot \
      -e "$REL_EFI_IMG" \
      -no-emul-boot \
      -isohybrid-gpt-basdat \
      -o "$ISO_PATH" \
      "$ISO_COPY"
  else
    echo "Creating ISO without isohdpfx.bin..."
    xorriso -as mkisofs \
      -volid "VOID_LIVE" \
      -c isolinux/boot.cat \
      -b "$REL_ISOLINUX_BIN" \
      -no-emul-boot \
      -boot-load-size 4 \
      -boot-info-table \
      -eltorito-alt-boot \
      -e "$REL_EFI_IMG" \
      -no-emul-boot \
      -o "$ISO_PATH" \
      "$ISO_COPY"
  fi
else
  if [ -n "$ISOHDPFX_PATH" ]; then
    echo "Creating ISO without EFI support..."
    xorriso -as mkisofs \
      -volid "VOID_LIVE" \
      -isohybrid-mbr "$ISOHDPFX_PATH" \
      -c isolinux/boot.cat \
      -b "$REL_ISOLINUX_BIN" \
      -no-emul-boot \
      -boot-load-size 4 \
      -boot-info-table \
      -isohybrid-gpt-basdat \
      -o "$ISO_PATH" \
      "$ISO_COPY"
  else
    xorriso -as mkisofs \
      -volid "VOID_LIVE" \
      -c isolinux/boot.cat \
      -b "$REL_ISOLINUX_BIN" \
      -no-emul-boot \
      -boot-load-size 4 \
      -boot-info-table \
      -o "$ISO_PATH" \
      "$ISO_COPY"
  fi
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

  sudo rm -rf "$WORKDIR"
  echo "ISO successfully created!"
else
  echo "ERROR: Failed to create ISO"
  echo "Work directory preserved at: $WORKDIR"
  echo "Last 20 lines of possible error log:"
  tail -20 "$WORKDIR/mksquashfs.log" 2>/dev/null || echo "No log file found"
  exit 1
fi
