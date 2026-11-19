#!/bin/sh
set -e
cd "$(dirname "$0")"
CONFIG=configs/templates/XIAOMI/rm-ac2100-adblock.config
if ! cmp -s "$CONFIG" .config; then
    cp "$CONFIG" .config
fi
./build_firmware.sh
