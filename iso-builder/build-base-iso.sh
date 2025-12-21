#!/bin/bash
set -e

if [ ! -d "void-mklive" ]; then
  echo "Cloning void-mklive repository..."
  git clone --depth=1 https://github.com/void-linux/void-mklive
fi

cd void-mklive

sudo ./mklive.sh \
  -a x86_64 \
  -r "https://repo-default.voidlinux.org/current" \
  -p "linux6.18 linux6.18-headers git curl wget" \
  -o "void-base-x86_64-$(date +%Y%m%d).iso"

echo "Base ISO created: void-base-x86_64-$(date +%Y%m%d).iso"
