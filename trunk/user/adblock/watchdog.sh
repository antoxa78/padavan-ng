#!/bin/sh
BIN=$(cd "$(dirname "$0")" && pwd)
WORK=/tmp/adblock
PID=/var/run/adblock-dnsmasq.pid

for L in update.lock start.lock; do
    if [ -f "$WORK/$L" ] && kill -0 "$(cat "$WORK/$L")" 2>/dev/null; then
        exit 0
    fi
done

if [ "$(nvram get adblock_enable)" = "0" ]; then
    exit 0
fi
if [ "$(nvram get sw_mode)" != "3" ]; then
    exit 0
fi

if [ -s "$PID" ] && kill -0 "$(cat "$PID")" 2>/dev/null; then
    if [ -s "$WORK/hosts.v4" ] && [ -s "$WORK/hosts.v6" ]; then
        exit 0
    fi
    # Resolver is alive but a list vanished: rebuild at most every 5 min.
    STAMP=$WORK/last_rebuild
    NOW=$(date +%s)
    if [ -f "$STAMP" ] && [ $((NOW - $(cat "$STAMP"))) -lt 300 ]; then
        exit 0
    fi
    echo "$NOW" > "$STAMP"
    "$BIN/start.sh" >/dev/null 2>&1
    exit 0
fi

"$BIN/start.sh" >/dev/null 2>&1
