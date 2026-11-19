#!/bin/sh
set -e
cd "$(dirname "$0")"

# Fast path for adblock scripts, the web UI and other user-space changes.
# It reuses the toolchain, kernel and package build trees.
CONFIG_TOOLCHAIN_DIR="${CONFIG_TOOLCHAIN_DIR:-$(cd ../toolchain/out && pwd)}"
export CONFIG_TOOLCHAIN_DIR
touch user/rc/common_ex.c
make user_only
if command -v fakeroot >/dev/null 2>&1; then
    fakeroot make romfs image
else
    make romfs image
fi
