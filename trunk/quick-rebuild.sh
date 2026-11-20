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

# CI-style image budget: fail above the flash limit, warn above 8 MiB.
IMG=$(ls -t images/RM-AC2100_*.trx 2>/dev/null | head -1)
if [ -n "$IMG" ]; then
    SIZE=$(stat -c %s "$IMG")
    MAX=20971520
    BUDGET=8388608
    if [ "$SIZE" -gt "$MAX" ]; then
        echo "ERROR: $IMG is $SIZE bytes (max $MAX)" >&2
        exit 1
    fi
    if [ "$SIZE" -gt "$BUDGET" ]; then
        echo "WARNING: $IMG is $SIZE bytes (budget $BUDGET)" >&2
    else
        echo "image: $IMG ($SIZE bytes, within $BUDGET-byte budget)"
    fi
fi
