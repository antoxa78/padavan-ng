#!/bin/sh
# Allow a recently blocked domain: persist it, remove it from the live hosts
# lists, refresh the gzip and reload the resolver without a full update.
BIN=$(cd "$(dirname "$0")" && pwd)
DIR=/etc/storage/adblock
WORK=/tmp/adblock

D=$(nvram get adblock_allow_add)
D=$(printf '%s' "$D" | tr -d '\r' | tr 'A-Z' 'a-z' |
    sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
case "$D" in
    ''|*[!a-z0-9.-]*) ;;
    *.*) ;;
    *) D="";;
esac
case "$D" in
    .*|*.|*..*) D="";;
esac

if [ -z "$D" ]; then
    nvram set adblock_allow_add=""
    nvram set adblock_status="allow failed: invalid domain"
    nvram commit
    exit 1
fi

if [ -f "$WORK/update.lock" ] && kill -0 "$(cat "$WORK/update.lock")" 2>/dev/null; then
    nvram set adblock_allow_add=""
    nvram set adblock_status="allow failed: update in progress"
    nvram commit
    exit 1
fi

mkdir -p "$DIR" "$WORK"
OLD_CONFIG_HASH=$(nvram get adblock_config_hash)
OLD_APPLIED_HASH=$(nvram get adblock_applied_hash)
OLD_APPLIED_OPTIONS_HASH=$(nvram get adblock_applied_options_hash)
if [ -f "$DIR/custom.allow" ]; then
    tr -d '\r' < "$DIR/custom.allow" > "$DIR/custom.allow.new" &&
        mv "$DIR/custom.allow.new" "$DIR/custom.allow"
fi
if ! grep -qxF "$D" "$DIR/custom.allow" 2>/dev/null; then
    printf '%s\n' "$D" >> "$DIR/custom.allow"
fi
nvram set adblock_allow="$(cat "$DIR/custom.allow")"

D_ESC=$(printf '%s' "$D" | sed 's/\./\\./g')
for f in "$WORK/hosts.v4" "$WORK/hosts.v6"; do
    [ -f "$f" ] || continue
    grep -vE "^((0\.0\.0\.0)|(::1)) ([a-z0-9_.-]+\.)?${D_ESC}$" "$f" > "$f.tmp"
    mv "$f.tmp" "$f"
done
chmod 644 "$WORK/hosts.v4" "$WORK/hosts.v6" 2>/dev/null

gzip -9 -c "$WORK/hosts.v4" > "$DIR/hosts.gz.new" 2>/dev/null &&
    mv "$DIR/hosts.gz.new" "$DIR/hosts.gz"
rm -f "$DIR/hosts.gz.new"

CONFIG_HASH=$( { cat "$DIR/sources.conf"; echo '---'; cat "$DIR/custom.hosts"; echo '---'; cat "$DIR/custom.allow"; echo '---'; cat "$DIR/wildcard.conf"; echo '---'; cat "$DIR/options.conf"; echo '---'; cat "$DIR/doh.conf"; } | md5sum | cut -d' ' -f1)
OPTIONS_HASH=$( { cat "$DIR/wildcard.conf"; echo '---'; cat "$DIR/options.conf"; echo '---'; cat "$DIR/doh.conf"; } | md5sum | cut -d' ' -f1)
LINES=$(grep -c '^0\.0\.0\.0 ' "$WORK/hosts.v4")

if [ "$OLD_CONFIG_HASH" = "$OLD_APPLIED_HASH" ] && [ "$OLD_APPLIED_OPTIONS_HASH" = "$OPTIONS_HASH" ]; then
    nvram set adblock_applied_hash="$CONFIG_HASH"
    nvram set adblock_applied_options_hash="$OPTIONS_HASH"
    nvram set adblock_config_dirty=0
else
    # Unapplied wildcard/DoH/custom changes remain pending.
    nvram set adblock_config_dirty=1
fi
nvram set adblock_allow_add=""

PAUSE=$(nvram get adblock_pause_until)
case "$PAUSE" in ''|*[!0-9]*) PAUSE=0;; esac
if [ "$PAUSE" -gt "$(date +%s)" ] 2>/dev/null; then
    nvram set adblock_status="paused (allowed $D)"
    nvram set adblock_phase=paused
else
    if [ "$(nvram get sw_mode)" = "3" ]; then
        if [ -s /var/run/adblock-dnsmasq.pid ] &&
                kill -0 "$(cat /var/run/adblock-dnsmasq.pid)" 2>/dev/null; then
            kill -HUP "$(cat /var/run/adblock-dnsmasq.pid)" 2>/dev/null
        else
            "$BIN/restart.sh" >/dev/null 2>&1
        fi
    else
        killall -HUP dnsmasq 2>/dev/null
    fi
    nvram set adblock_status="$LINES domains (allowed $D)"
    nvram set adblock_phase=idle
fi
nvram set adblock_progress=""
nvram commit
/sbin/mtd_storage.sh save >/dev/null 2>&1
logger -t adblock "allowed $D; $LINES domains"
