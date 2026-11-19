#!/bin/sh
BIN=/usr/sbin/adblock
DIR=/etc/storage/adblock

SRC=$(nvram get adblock_sources)
if [ -z "$SRC" ]; then
    SRC="$(cat "$BIN/defaults/sources.conf")"
    nvram set adblock_sources="$SRC"
    nvram commit
fi
printf '%s\n' "$SRC" > "$DIR/sources.conf"

CUSTOM=$(nvram get adblock_custom)
if [ -n "$CUSTOM" ]; then
    printf '%s\n' "$CUSTOM" > "$DIR/custom.hosts"
else
    : > "$DIR/custom.hosts"
fi

ALLOW=$(nvram get adblock_allow)
if [ -z "$ALLOW" ]; then
    ALLOW='# no allowlist'
    nvram set adblock_allow="$ALLOW"
    nvram commit
fi
printf '%s\n' "$ALLOW" > "$DIR/custom.allow"

if [ "$(nvram get adblock_enable)" = "0" ]; then
    "$BIN/stop.sh"
else
    "$BIN/start.sh" >/dev/null 2>&1
    nvram set adblock_status="updating..."
    nvram commit
    "$BIN/update.sh" >/tmp/adblock-update.log 2>&1 &
fi
