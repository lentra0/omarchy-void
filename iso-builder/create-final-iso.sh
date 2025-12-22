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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKDIR="$SCRIPT_DIR/work/iso-build"
ISO_MOUNT="$WORKDIR/iso-mount"
ISO_COPY="$WORKDIR/iso-copy"

echo "=== Creating final ISO ==="

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

sudo cp -a "$ISO_MOUNT/." "$ISO_COPY/"

sudo umount "$ISO_MOUNT"
echo "ISO structure copied successfully"

echo "Fixing permissions on ISO files..."
sudo chmod -R a+r "$ISO_COPY"
sudo find "$ISO_COPY" -type d -exec chmod a+rx {} \;

FILES_TO_FIX=(
  "$ISO_COPY/boot/initrd"
  "$ISO_COPY/boot/vmlinuz"
  "$ISO_COPY/boot/isolinux/isolinux.bin"
  "$ISO_COPY/boot/isolinux/boot.cat"
  "$ISO_COPY/boot/grub/efiboot.img"
)

for file in "${FILES_TO_FIX[@]}"; do
  if [ -f "$file" ]; then
    echo "Setting read permissions on $(basename "$file")..."
    sudo chmod 644 "$file"
  fi
done

SQUASHFS_DEST="$ISO_COPY/LiveOS/squashfs.img"
if [ ! -d "$(dirname "$SQUASHFS_DEST")" ]; then
  echo "Creating LiveOS directory..."
  sudo mkdir -p "$(dirname "$SQUASHFS_DEST")"
fi

echo "Creating new squashfs at: $SQUASHFS_DEST"
echo "Compressing chroot directory ($(sudo du -sh "$CHROOT_DIR" | cut -f1))..."

sudo mksquashfs "$CHROOT_DIR" "$SQUASHFS_DEST" \
  -comp xz \
  -b 1M \
  -noappend \
  -no-recovery \
  -mem 2G

echo "Squashfs created: $(sudo du -h "$SQUASHFS_DEST" | cut -f1)"

DATE=$(date +%Y%m%d)
ISO_NAME="omarchy-void-$DATE-x86_64.iso"

OUTPUT_DIR=$(realpath -m "$OUTPUT_DIR")
mkdir -p "$OUTPUT_DIR"
ISO_PATH="$OUTPUT_DIR/$ISO_NAME"

echo "Creating ISO: $ISO_PATH..."

if [ -f "$ISO_PATH" ]; then
  echo "Removing old ISO file: $ISO_PATH"
  rm -f "$ISO_PATH"
fi

echo "Verifying critical files..."
CRITICAL_FILES=(
  "$ISO_COPY/boot/isolinux/isolinux.bin"
  "$ISO_COPY/boot/grub/efiboot.img"
  "$ISO_COPY/boot/initrd"
  "$ISO_COPY/boot/vmlinuz"
)

for file in "${CRITICAL_FILES[@]}"; do
  if [ ! -f "$file" ]; then
    echo "Error: Required file not found: $file"
    exit 1
  fi
  echo "Found: $file"
done

echo "Building ISO with xorriso..."

if [ ! -f "$ISO_COPY/boot/isolinux/boot.cat" ]; then
  echo "Creating boot.cat file..."
  cd "$ISO_COPY"
  genisoimage -no-emul-boot -boot-load-size 4 -boot-info-table -o /dev/null -c boot/isolinux/boot.cat -b boot/isolinux/isolinux.bin .
  cd - >/dev/null
fi

ISOHDPFX_PATH=""
for path in "/usr/lib/syslinux/isohdpfx.bin" "/usr/share/syslinux/isohdpfx.bin" "/usr/lib/ISOLINUX/isohdpfx.bin" "/usr/lib/syslinux/bios/isohdpfx.bin"; do
  if [ -f "$path" ]; then
    ISOHDPFX_PATH="$path"
    echo "Found isohdpfx.bin at: $ISOHDPFX_PATH"
    break
  fi
done

cd "$ISO_COPY"

if [ -n "$ISOHDPFX_PATH" ]; then
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
    .
else
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
    .
fi

XORRISO_RET=$?
cd - >/dev/null

if [ $XORRISO_RET -eq 0 ] && [ -f "$ISO_PATH" ]; then
  echo ""
  echo "=== Final ISO created: $ISO_PATH ==="
  echo "Size: $(du -h "$ISO_PATH" | cut -f1)"

  if [ "$(id -u)" != "0" ]; then
    sudo chown $(id -u):$(id -g) "$ISO_PATH"
  fi

  echo "Creating checksum..."
  (cd "$OUTPUT_DIR" && sha256sum "$ISO_NAME" >"$ISO_NAME.sha256")

  sudo rm -rf "$WORKDIR"
  echo "ISO successfully created!"
  exit 0
fi

echo "ERROR: Failed to create ISO with xorriso (code: $XORRISO_RET)"

echo "Trying alternative method with genisoimage..."

if command -v genisoimage >/dev/null 2>&1; then
  cd "$ISO_COPY"

  genisoimage \
    -volid "VOID_LIVE" \
    -rational-rock \
    -joliet \
    -full-iso9660-filenames \
    -c "boot/isolinux/boot.cat" \
    -b "boot/isolinux/isolinux.bin" \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -eltorito-alt-boot \
    -e "boot/grub/efiboot.img" \
    -no-emul-boot \
    -o "$ISO_PATH" .

  GENISO_RET=$?
  cd - >/dev/null

  if [ $GENISO_RET -eq 0 ] && [ -f "$ISO_PATH" ]; then
    echo "ISO created successfully with genisoimage!"

    if [ "$(id -u)" != "0" ]; then
      sudo chown $(id -u):$(id -g) "$ISO_PATH"
    fi

    (cd "$OUTPUT_DIR" && sha256sum "$ISO_NAME" >"$ISO_NAME.sha256")
    sudo rm -rf "$WORKDIR"
    exit 0
  fi
fi

echo "ERROR: All methods failed"
exit 1
