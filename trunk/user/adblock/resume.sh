#!/bin/sh
# Restore DNS filtering after a pause.  The live lists are decompressed from
# the persisted gzip so no network download is needed.
BIN=$(cd "$(dirname "$0")" && pwd)
DIR=/etc/storage/adblock
WORK=/tmp/adblock
PID=/var/run/adblock-dnsmasq.pid

mkdir -p "$WORK"

RESTORED=0
if [ -s "$DIR/hosts.gz" ]; then
    if gzip -dc "$DIR/hosts.gz" > "$WORK/hosts.v4.tmp" 2>/dev/null && [ -s "$WORK/hosts.v4.tmp" ]; then
        mv "$WORK/hosts.v4.tmp" "$WORK/hosts.v4"
        sed 's/^0\.0\.0\.0 /::1 /' "$WORK/hosts.v4" > "$WORK/hosts.v6.tmp" 2>/dev/null &&
            mv "$WORK/hosts.v6.tmp" "$WORK/hosts.v6"
        RESTORED=1
    else
        rm -f "$WORK/hosts.v4.tmp"
    fi
fi

if [ "$RESTORED" = "1" ]; then
    chmod 644 "$WORK/hosts.v4" "$WORK/hosts.v6"
    if [ "$(nvram get sw_mode)" = "3" ]; then
        if [ -s "$PID" ] && kill -0 "$(cat "$PID")" 2>/dev/null; then
            kill -HUP "$(cat "$PID")" 2>/dev/null
        else
            "$BIN/restart.sh" >/dev/null 2>&1
        fi
    else
        killall -HUP dnsmasq 2>/dev/null
    fi
    LINES=$(grep -c '^0\.0\.0\.0 ' "$WORK/hosts.v4")
    nvram set adblock_pause_until=0
    nvram set adblock_phase=idle
    nvram set adblock_progress=""
    nvram set adblock_status="$LINES domains (resumed)"
    nvram commit
    logger -t adblock "resumed with $LINES domains"
else
    # No persisted list: clear the pause and let start.sh rebuild normally.
    nvram set adblock_pause_until=0
    nvram commit
    "$BIN/start.sh" >/dev/null 2>&1
fi
