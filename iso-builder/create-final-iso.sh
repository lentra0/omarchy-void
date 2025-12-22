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

(cd "$ISO_MOUNT" && sudo tar cf - .) | (cd "$ISO_COPY" && sudo tar xpf -) 2>/dev/null || {
  echo "Error: Failed to copy ISO structure"
  sudo umount "$ISO_MOUNT"
  exit 1
}

sudo umount "$ISO_MOUNT"
echo "ISO structure copied successfully"

SQUASHFS_DEST="$ISO_COPY/LiveOS/squashfs.img"
if [ ! -d "$(dirname "$SQUASHFS_DEST")" ]; then
  echo "Error: LiveOS directory not found in ISO"
  exit 1
fi

mkdir -p "$(dirname "$SQUASHFS_DEST")"

echo "Creating new squashfs at: $SQUASHFS_DEST"
echo "Compressing chroot directory ($(sudo du -sh "$CHROOT_DIR" | cut -f1))..."

sudo mksquashfs "$CHROOT_DIR" "$SQUASHFS_DEST" \
  -comp xz \
  -b 1M \
  -noappend \
  -no-recovery \
  -mem 2G 2>&1 | tee "$WORKDIR/mksquashfs.log" || {
  echo "Error: Failed to create squashfs"
  exit 1
}

echo "Squashfs created: $(sudo du -h "$SQUASHFS_DEST" | cut -f1)"

DATE=$(date +%Y%m%d)
ISO_NAME="omarchy-void-$DATE-x86_64.iso"
ISO_PATH="$OUTPUT_DIR/$ISO_NAME"

mkdir -p "$OUTPUT_DIR"

echo "Creating ISO: $ISO_PATH..."

if [ -f "$ISO_PATH" ]; then
  echo "Removing old ISO file: $ISO_PATH"
  rm -f "$ISO_PATH"
fi

ISOLINUX_BIN="$ISO_COPY/boot/isolinux/isolinux.bin"
EFI_IMG="$ISO_COPY/boot/grub/efiboot.img"

if [ ! -f "$ISOLINUX_BIN" ]; then
  echo "Error: isolinux.bin not found at $ISOLINUX_BIN"
  exit 1
fi

if [ ! -f "$EFI_IMG" ]; then
  echo "Error: efiboot.img not found at $EFI_IMG"
  exit 1
fi

echo "Building ISO with xorriso..."

cd "$ISO_COPY" && sudo xorriso -as mkisofs \
  -volid "VOID_LIVE" \
  -isohybrid-mbr /usr/lib/syslinux/isohdpfx.bin \
  -c "boot/isolinux/boot.cat" \
  -b "boot/isolinux/isolinux.bin" \
  -no-emul-boot \
  -boot-load-size 4 \
  -boot-info-table \
  -eltorito-alt-boot \
  -e "boot/grub/efiboot.img" \
  -no-emul-boot \
  -isohybrid-gpt-basdat \
  -o "$ISO_PATH" . 2>&1 | tee "$WORKDIR/xorriso.log"

cd - >/dev/null

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
  echo "Xorriso log:"
  tail -20 "$WORKDIR/xorriso.log" 2>/dev/null || echo "No log file found"

  echo "Trying alternative method with genisoimage..."
  if command -v genisoimage >/dev/null 2>&1; then
    cd "$ISO_COPY" && sudo genisoimage \
      -volid "VOID_LIVE" \
      -c "boot/isolinux/boot.cat" \
      -b "boot/isolinux/isolinux.bin" \
      -no-emul-boot \
      -boot-load-size 4 \
      -boot-info-table \
      -eltorito-alt-boot \
      -e "boot/grub/efiboot.img" \
      -no-emul-boot \
      -o "$ISO_PATH" . 2>&1 | tee "$WORKDIR/genisoimage.log"

    cd - >/dev/null

    if [ $? -eq 0 ] && [ -f "$ISO_PATH" ]; then
      echo "ISO created successfully with genisoimage!"
      if [ "$(id -u)" != "0" ]; then
        sudo chown $(id -u):$(id -g) "$ISO_PATH" 2>/dev/null || true
      fi
      (cd "$OUTPUT_DIR" && sha256sum "$ISO_NAME" >"$ISO_NAME.sha256")
      sudo rm -rf "$WORKDIR"
    else
      echo "ERROR: Both xorriso and genisoimage failed"
      echo "Work directory preserved at: $WORKDIR"
      exit 1
    fi
  else
    echo "Error: genisoimage not available"
    echo "You can install it with: sudo xbps-install -S cdrkit"
    exit 1
  fi
fi
