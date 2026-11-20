#!/bin/sh
# Temporarily disable DNS filtering without stopping the resolver.
BIN=$(cd "$(dirname "$0")" && pwd)
WORK=/tmp/adblock
PID=/var/run/adblock-dnsmasq.pid

MIN=$(nvram get adblock_pause_minutes)
case "$MIN" in ''|*[!0-9]*) MIN=60;; esac
[ "$MIN" -lt 1 ] && MIN=1
[ "$MIN" -gt 1440 ] && MIN=1440

mkdir -p "$WORK"
: > "$WORK/hosts.v4"
: > "$WORK/hosts.v6"
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

NOW=$(date +%s)
UNTIL=$((NOW + MIN * 60))
nvram set adblock_pause_until="$UNTIL"
nvram set adblock_phase=paused
nvram set adblock_progress=""
nvram set adblock_status="paused (DNS filtering off)"
nvram commit
logger -t adblock "paused for $MIN minutes (until epoch $UNTIL)"
echo "paused until $UNTIL"
