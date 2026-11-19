#!/bin/sh
DIR=/etc/storage/adblock
PID=/var/run/adblock-dnsmasq.pid

# Stop any existing adblock dnsmasq, even if the pidfile is stale.
if [ -s "$PID" ]; then
    kill "$(cat "$PID")" 2>/dev/null
fi
for p in $(pidof dnsmasq); do
    if tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null | grep -q 'adblock/dnsmasq.conf'; then
        kill "$p" 2>/dev/null
    fi
done
sleep 1

dnsmasq --test -C "$DIR/dnsmasq.conf" >/dev/null 2>&1 || exit 1
dnsmasq -C "$DIR/dnsmasq.conf" --pid-file="$PID" || exit 1

# Wait for dnsmasq to finish loading and write its pidfile.
i=0
while [ "$i" -lt 30 ]; do
    if [ -s "$PID" ] && kill -0 "$(cat "$PID")" 2>/dev/null; then
        exit 0
    fi
    sleep 1
    i=$((i + 1))
done
exit 1
