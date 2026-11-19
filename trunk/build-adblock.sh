#!/bin/sh
set -e
cd "$(dirname "$0")"
cp configs/templates/XIAOMI/rm-ac2100-adblock.config .config
./build_firmware.sh
