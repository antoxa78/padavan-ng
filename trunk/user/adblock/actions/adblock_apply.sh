#!/bin/sh
BIN=/usr/sbin/adblock
DIR=/etc/storage/adblock

PRESETS=$BIN/defaults/presets.conf
MASK=$(nvram get adblock_presets)
case "$MASK" in ''|*[!0-9]*) MASK=127;; esac
EXTRA=$(nvram get adblock_extra_sources)
: > "$DIR/sources.conf"
while IFS='|' read -r idx label url; do
    case "$idx" in ''|'#'*) continue;; esac
    if [ $((MASK & (1 << idx))) -ne 0 ]; then
        echo "$url" >> "$DIR/sources.conf"
    fi
done < "$PRESETS"
if [ -n "$EXTRA" ]; then
    printf '%s\n' "$EXTRA" >> "$DIR/sources.conf"
fi
if [ ! -s "$DIR/sources.conf" ] && [ "$MASK" -ne 0 ]; then
    cp "$BIN/defaults/sources.conf" "$DIR/sources.conf"
    nvram set adblock_presets=127
fi
nvram set adblock_sources="$(cat "$DIR/sources.conf")"
nvram commit

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
