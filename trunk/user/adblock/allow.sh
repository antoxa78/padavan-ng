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
    ''|*[!a-z0-9.-]*) D="";;
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

mkdir -p "$DIR" "$WORK"

allow_fail() {
    nvram set adblock_allow_add=""
    nvram set adblock_status="$1"
    nvram commit
    exit 1
}

ALOCK=$WORK/allow.lock
if [ -f "$WORK/update.lock" ] && kill -0 "$(cat "$WORK/update.lock")" 2>/dev/null; then
    allow_fail "allow failed: update in progress"
fi
if [ -f "$ALOCK" ] && kill -0 "$(cat "$ALOCK")" 2>/dev/null; then
    allow_fail "allow failed: another allow in progress"
fi
echo $$ > "$ALOCK"
trap 'rm -f "$ALOCK"' EXIT

# Re-check after taking our lock so an update cannot start unnoticed.
if [ -f "$WORK/update.lock" ] && kill -0 "$(cat "$WORK/update.lock")" 2>/dev/null; then
    allow_fail "allow failed: update in progress"
fi

OLD_CONFIG_HASH=$(nvram get adblock_config_hash)
OLD_APPLIED_HASH=$(nvram get adblock_applied_hash)
OLD_APPLIED_OPTIONS_HASH=$(nvram get adblock_applied_options_hash)
if [ -f "$DIR/custom.allow" ]; then
    tr -d '\r' < "$DIR/custom.allow" > "$DIR/custom.allow.new" &&
        mv "$DIR/custom.allow.new" "$DIR/custom.allow"
fi
if ! grep -qxF -- "$D" "$DIR/custom.allow" 2>/dev/null; then
    printf '%s\n' "$D" >> "$DIR/custom.allow"
fi
nvram set adblock_allow="$(cat "$DIR/custom.allow")"

PAUSE=$(nvram get adblock_pause_until)
case "$PAUSE" in ''|*[!0-9]*) PAUSE=0;; esac
PAUSED=0
[ "$PAUSE" -gt "$(date +%s)" ] 2>/dev/null && PAUSED=1

D_ESC=$(printf '%s' "$D" | sed 's/\./\\./g')
FILTER="^((0\\.0\\.0\\.0)|(::1)) ([a-z0-9_.-]+\\.)?${D_ESC}$"
LIVE_HAD_LINES=0
[ -s "$WORK/hosts.v4" ] && LIVE_HAD_LINES=1
LIST_ERROR=0
for f in "$WORK/hosts.v4" "$WORK/hosts.v6"; do
    [ -f "$f" ] || continue
    grep -vE "$FILTER" "$f" > "$f.tmp"
    rc=$?
    if [ "$rc" -le 1 ]; then
        mv "$f.tmp" "$f"
    else
        rm -f "$f.tmp"
        LIST_ERROR=1
    fi
done
chmod 644 "$WORK/hosts.v4" "$WORK/hosts.v6" 2>/dev/null

if [ "$LIST_ERROR" = "0" ]; then
    if [ "$PAUSED" = "1" ]; then
        # Live lists are intentionally empty while paused, so remove the domain
        # from the persisted copy as well or it returns when filtering resumes.
        if [ -s "$DIR/hosts.gz" ]; then
            if gzip -dc "$DIR/hosts.gz" > "$WORK/hosts.paused" 2>/dev/null; then
                grep -vE "$FILTER" "$WORK/hosts.paused" > "$WORK/hosts.paused.new"
                rc=$?
                if [ "$rc" -le 1 ] &&
                        gzip -9 -c "$WORK/hosts.paused.new" > "$DIR/hosts.gz.new" 2>/dev/null; then
                    chmod 644 "$DIR/hosts.gz.new"
                    mv "$DIR/hosts.gz.new" "$DIR/hosts.gz"
                else
                    LIST_ERROR=1
                fi
            else
                LIST_ERROR=1
            fi
            rm -f "$WORK/hosts.paused" "$WORK/hosts.paused.new" "$DIR/hosts.gz.new"
        fi
    elif [ "$LIVE_HAD_LINES" = "1" ] || [ -s "$WORK/hosts.v4" ]; then
        gzip -9 -c "$WORK/hosts.v4" > "$DIR/hosts.gz.new" 2>/dev/null &&
            chmod 644 "$DIR/hosts.gz.new" &&
            mv "$DIR/hosts.gz.new" "$DIR/hosts.gz"
        rm -f "$DIR/hosts.gz.new"
    fi
fi

CONFIG_HASH=$( { cat "$DIR/sources.conf"; echo '---'; cat "$DIR/custom.hosts"; echo '---'; cat "$DIR/custom.allow"; echo '---'; cat "$DIR/wildcard.conf"; echo '---'; cat "$DIR/options.conf"; echo '---'; cat "$DIR/doh.conf"; } | md5sum | cut -d' ' -f1)
OPTIONS_HASH=$( { cat "$DIR/wildcard.conf"; echo '---'; cat "$DIR/options.conf"; echo '---'; cat "$DIR/doh.conf"; } | md5sum | cut -d' ' -f1)
nvram set adblock_config_hash="$CONFIG_HASH"
LINES=$(grep -c '^0\.0\.0\.0 ' "$WORK/hosts.v4")

if [ "$LIST_ERROR" = "0" ] &&
        [ "$OLD_CONFIG_HASH" = "$OLD_APPLIED_HASH" ] &&
        [ "$OLD_APPLIED_OPTIONS_HASH" = "$OPTIONS_HASH" ]; then
    nvram set adblock_applied_hash="$CONFIG_HASH"
    nvram set adblock_applied_options_hash="$OPTIONS_HASH"
    nvram set adblock_config_dirty=0
else
    # Unapplied wildcard/DoH/custom changes remain pending.
    nvram set adblock_config_dirty=1
fi
nvram set adblock_allow_add=""

if [ "$LIST_ERROR" = "1" ]; then
    nvram set adblock_status="allow failed: list update error"
    nvram set adblock_phase=error
elif [ "$PAUSED" = "1" ] && [ "$PAUSE" -gt "$(date +%s)" ] 2>/dev/null; then
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
