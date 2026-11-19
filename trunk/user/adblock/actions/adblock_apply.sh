#!/bin/sh
BIN=/usr/sbin/adblock
DIR=/etc/storage/adblock

SRC=$(nvram get adblock_sources)
if [ -n "$SRC" ]; then
    printf '%s\n' "$SRC" > "$DIR/sources.conf"
else
    cp "$BIN/defaults/sources.conf" "$DIR/sources.conf"
fi

CUSTOM=$(nvram get adblock_custom)
if [ -n "$CUSTOM" ]; then
    printf '%s\n' "$CUSTOM" > "$DIR/custom.hosts"
else
    : > "$DIR/custom.hosts"
fi

if [ "$(nvram get adblock_enable)" = "0" ]; then
    "$BIN/stop.sh"
else
    "$BIN/start.sh" >/dev/null 2>&1
    nvram set adblock_status="updating..."
    nvram commit
    "$BIN/update.sh" >/tmp/adblock-update.log 2>&1 &
fi
