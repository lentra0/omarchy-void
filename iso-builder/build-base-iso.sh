#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$SCRIPT_DIR/work/base"
mkdir -p "$BASE_DIR"

EXISTING_ISO=$(find "$BASE_DIR" -name "void-base-x86_64-*.iso" -type f 2>/dev/null | head -1)

if [ -n "$EXISTING_ISO" ]; then
  echo "Found existing base ISO: $EXISTING_ISO"
  echo "Skipping base ISO build."
  exit 0
fi

if [ ! -d "void-mklive" ]; then
  echo "Cloning void-mklive repository..."
  git clone --depth=1 https://github.com/void-linux/void-mklive
fi

cd void-mklive

sudo rm -f void-base-x86_64-*.iso

echo "Building base ISO..."
sudo ./mklive.sh \
  -a x86_64 \
  -r "https://repo-default.voidlinux.org/current" \
  -p "linux6.18 linux6.18-headers git curl wget" \
  -o "$BASE_DIR/void-base-x86_64-$(date +%Y%m%d).iso"

if ls "$BASE_DIR"/void-base-x86_64-*.iso 1>/dev/null 2>&1; then
  echo "Base ISO created: $(ls $BASE_DIR/void-base-x86_64-*.iso)"
else
  echo "Error: Failed to create base ISO"
  exit 1
fi
