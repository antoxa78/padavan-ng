#!/bin/sh
set -e
cd "$(dirname "$0")"

# Fast path for adblock scripts, the web UI and other user-space changes.
# It reuses the toolchain, kernel and package build trees.
make user_only
make romfs image
