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

echo "Fixing permissions on ISO files..."
sudo chmod -R a+r "$ISO_COPY" 2>/dev/null || true

if [ -f "$ISO_COPY/boot/initrd" ]; then
  echo "Setting read permissions on initrd..."
  sudo chmod 644 "$ISO_COPY/boot/initrd" 2>/dev/null || true
fi

if [ -f "$ISO_COPY/boot/vmlinuz" ]; then
  echo "Setting read permissions on vmlinuz..."
  sudo chmod 644 "$ISO_COPY/boot/vmlinuz" 2>/dev/null || true
fi

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
  -mem 2G 2>&1 || {
  echo "Error: Failed to create squashfs"
  exit 1
}

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

if [ ! -f "$ISO_COPY/boot/isolinux/boot.cat" ]; then
  echo "Creating boot.cat..."
  cd "$ISO_COPY"
  xorriso -as mkisofs \
    -o /dev/null \
    -c "boot/isolinux/boot.cat" \
    -b "boot/isolinux/isolinux.bin" \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    . >/dev/null 2>&1 || true
  cd - >/dev/null
fi

ISOHDPFX_PATH=""
for path in "/usr/lib/syslinux/isohdpfx.bin" "/usr/share/syslinux/isohdpfx.bin" "/usr/lib/ISOLINUX/isohdpfx.bin" "/usr/lib/syslinux/bios/isohdpfx.bin"; do
  if [ -f "$path" ]; then
    ISOHDPFX_PATH="$path"
    break
  fi
done

echo "Verifying file permissions..."
CRITICAL_FILES=("$ISO_COPY/boot/initrd" "$ISO_COPY/boot/vmlinuz" "$ISOLINUX_BIN" "$EFI_IMG")
for file in "${CRITICAL_FILES[@]}"; do
  if [ -f "$file" ]; then
    perms=$(stat -c "%A" "$file" 2>/dev/null || echo "unknown")
    echo "  $(basename "$file"): $perms"
    if [ "$perms" != "-r--r--r--" ] && [ "$perms" != "-rw-r--r--" ]; then
      echo "  Fixing permissions on $file"
      sudo chmod 644 "$file" 2>/dev/null || true
    fi
  fi
done

echo "Creating ISO with absolute path: $ISO_PATH"
cd "$ISO_COPY"

XORRISO_CMD="xorriso -as mkisofs \
  -volid 'VOID_LIVE' \
  -c 'boot/isolinux/boot.cat' \
  -b 'boot/isolinux/isolinux.bin' \
  -no-emul-boot \
  -boot-load-size 4 \
  -boot-info-table \
  -eltorito-alt-boot \
  -e 'boot/grub/efiboot.img' \
  -no-emul-boot \
  -o '$ISO_PATH'"

if [ -n "$ISOHDPFX_PATH" ]; then
  echo "Creating hybrid ISO with isohdpfx.bin..."
  XORRISO_CMD="xorriso -as mkisofs \
    -volid 'VOID_LIVE' \
    -isohybrid-mbr '$ISOHDPFX_PATH' \
    -c 'boot/isolinux/boot.cat' \
    -b 'boot/isolinux/isolinux.bin' \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -eltorito-alt-boot \
    -e 'boot/grub/efiboot.img' \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    -o '$ISO_PATH'"
fi

eval "$XORRISO_CMD" 2>&1 | grep -v "libburn\|libisofs" || true

XORRISO_RET=${PIPESTATUS[0]}
cd - >/dev/null

if [ $XORRISO_RET -eq 0 ] && [ -f "$ISO_PATH" ]; then
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
  echo "ERROR: Failed to create ISO with xorriso (code: $XORRISO_RET)"

  echo "Trying alternative method..."

  cd "$ISO_COPY"

  TEMP_ISO="$WORKDIR/temp.iso"
  xorriso -as mkisofs \
    -volid "VOID_LIVE" \
    -c "boot/isolinux/boot.cat" \
    -b "boot/isolinux/isolinux.bin" \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -o "$TEMP_ISO" . 2>/dev/null

  if [ -f "$TEMP_ISO" ]; then
    echo "Temporary ISO created, adding EFI boot image..."

    xorriso -indev "$TEMP_ISO" \
      -boot_image any replay \
      -append_partition 2 0xef "$EFI_IMG" \
      -outdev "$ISO_PATH" 2>/dev/null

    if [ -f "$ISO_PATH" ]; then
      echo "ISO created successfully with alternative method!"
      if [ "$(id -u)" != "0" ]; then
        sudo chown $(id -u):$(id -g) "$ISO_PATH" 2>/dev/null || true
      fi
      (cd "$OUTPUT_DIR" && sha256sum "$ISO_NAME" >"$ISO_NAME.sha256")
      sudo rm -rf "$WORKDIR"
      exit 0
    fi
  fi

  echo "ERROR: All methods failed"
  exit 1
fi
