#!/bin/sh
BIN=$(cd "$(dirname "$0")" && pwd)
DIR=/etc/storage/adblock
WORK=/tmp/adblock
SOURCES=$DIR/sources.conf
PID=/var/run/adblock-dnsmasq.pid
LOCK=$WORK/update.lock
LOG=/tmp/adblock-update.log
QLOG=/tmp/adblock-queries.log

mkdir -p "$WORK"
exec >> "$LOG" 2>&1

if [ -f "$LOCK" ] && kill -0 "$(cat "$LOCK")" 2>/dev/null; then
    echo "=== $(date '+%Y-%m-%d %H:%M:%S') update skipped: already running ==="
    logger -t adblock "update already running"
    exit 1
fi

: > "$LOG"
T0=$(date +%s)
START_TS=$(date '+%Y-%m-%d %H:%M')
echo "=== $START_TS update start ==="
echo $$ > "$LOCK"
trap 'rm -f "$LOCK"' EXIT

nvram set adblock_phase=downloading
nvram set adblock_progress="starting"
nvram set adblock_update_started="$START_TS"
nvram set adblock_last_attempt="$START_TS starting"
nvram set adblock_status="updating..."

SRC_STATUS=""

# Convert an HTTP Last-Modified value (RFC 1123, GMT) to local time.
http_date_to_local() {
    [ -n "$1" ] || return 1
    _lm_utc=$(date -D '%a, %d %b %Y %H:%M:%S GMT' -d "$1" '+%Y-%m-%d %H:%M' 2>/dev/null) ||
        _lm_utc=$(date -D '%a, %d %b %Y %H:%M:%S UTC' -d "$1" '+%Y-%m-%d %H:%M' 2>/dev/null) ||
        return 1
    _lm_epoch=$(date -u -D '%Y-%m-%d %H:%M' -d "$_lm_utc" '+%s' 2>/dev/null) || return 1
    date -d "@$_lm_epoch" '+%Y-%m-%d %H:%M' 2>/dev/null
}

fail_update() {
    REASON="$1"
    logger -t adblock "$REASON"
    echo "FAILED: $REASON"
    nvram set adblock_source_status="$SRC_STATUS"
    nvram set adblock_phase=error
    nvram set adblock_progress="$REASON"
    nvram set adblock_status="$REASON"
    nvram set adblock_last_attempt="$(date '+%Y-%m-%d %H:%M') failed: $REASON"
    nvram set adblock_config_dirty=1
    nvram commit
    rm -f "$LOCK"
    # Keep the previous list alive and preserve the error status.
    ADBLOCK_KEEP_STATUS=1 ADBLOCK_NO_UPDATE=1 "$BIN/start.sh" >/dev/null 2>&1
    exit 1
}

[ -f "$SOURCES" ] || : > "$SOURCES"
[ -s "$DIR/custom.allow" ] || echo '# no allowlist' > "$DIR/custom.allow"

# Snapshot the configuration for this run.  Settings saved while the update is
# running must not produce a half-old/half-new blocklist.
cp "$SOURCES" "$WORK/config.sources" 2>/dev/null || : > "$WORK/config.sources"
cp "$DIR/custom.hosts" "$WORK/config.custom" 2>/dev/null || : > "$WORK/config.custom"
cp "$DIR/custom.allow" "$WORK/config.allow" 2>/dev/null || : > "$WORK/config.allow"
CONFIG_HASH=$( { cat "$WORK/config.sources"; echo '---'; cat "$WORK/config.custom"; echo '---'; cat "$WORK/config.allow"; } | md5sum | cut -d' ' -f1)

rm -f "$WORK"/src.* "$WORK"/hosts.v4.raw "$WORK"/hosts.v4.new "$WORK"/hosts.v6.new \
      "$WORK"/hosts.gz.new "$WORK"/hosts.gz.bak "$WORK"/hosts

TOTAL=0
while IFS= read -r url; do
    case "$url" in ''|'#'*) continue;; esac
    TOTAL=$((TOTAL + 1))
done < "$WORK/config.sources"

N=0
OK=0
while IFS= read -r url; do
    case "$url" in ''|'#'*) continue;; esac
    N=$((N + 1))
    SRC_TS=$(date '+%m-%d %H:%M')
    nvram set adblock_progress="$N/$TOTAL sources"
    HDR="$WORK/hdr.$N"
    if wget -S -o "$HDR" -T 30 -O "$WORK/src.$N" "$url"; then
        LM=$(grep -i '^[[:space:]]*Last-Modified:' "$HDR" 2>/dev/null | tail -1 |
            sed 's/^[^:]*:[[:space:]]*//; s/\r$//')
        SRC_TIME=$(http_date_to_local "$LM" 2>/dev/null)
        SIZE=$(wc -c < "$WORK/src.$N")
        # Count domains this file can actually contribute, not raw lines.
        # A website URL downloads HTML with plenty of lines but no hosts data.
        SRC_LINES=$(tr -d '\r' < "$WORK/src.$N" 2>/dev/null |
            grep -cE '^(0\.0\.0\.0|127\.0\.0\.1|::1|::|255\.255\.255\.255)[[:space:]]+[a-zA-Z0-9_.-]+|^[a-zA-Z0-9_.-]+\.[a-zA-Z0-9_.-]+$')
        if [ "$SIZE" -gt 0 ] && [ "$SRC_LINES" -gt 0 ]; then
            OK=$((OK + 1))
            SRC_STATUS="$SRC_STATUS$url|$SRC_LINES|ok|$SRC_TS|$SRC_TIME
"
        else
            logger -t adblock "no usable domains: $url"
            SRC_STATUS="$SRC_STATUS$url|0|empty|$SRC_TS|$SRC_TIME
"
            rm -f "$WORK/src.$N"
        fi
    else
        logger -t adblock "download failed: $url"
        SRC_STATUS="$SRC_STATUS$url|0|failed|$SRC_TS|
"
        rm -f "$WORK/src.$N"
    fi
    rm -f "$HDR"
done < "$WORK/config.sources"

echo "sources: $OK/$TOTAL downloaded ($(($(date +%s) - T0))s)"
nvram set adblock_progress="$OK/$TOTAL sources downloaded"

HAS_CUSTOM=0
if grep -qEv '^[[:space:]]*(#|$)' "$WORK/config.custom" 2>/dev/null; then
    HAS_CUSTOM=1
fi
if [ "$OK" -eq 0 ] && [ "$HAS_CUSTOM" = "0" ]; then
    fail_update "update failed: no sources and no custom domains"
fi

# Keep the previous gzip in /tmp as a rollback copy.
[ -f "$DIR/hosts.gz" ] && cp "$DIR/hosts.gz" "$WORK/hosts.gz.bak"

nvram set adblock_phase=merging
nvram set adblock_progress="$OK/$TOTAL sources"

# Build the allowlist regex once (exact domains and their subdomains).
ALLOW_RE=$(grep -v '^[[:space:]]*#' "$WORK/config.allow" 2>/dev/null |
    tr -d '\r' | tr 'A-Z' 'a-z' |
    grep -E '^[a-z0-9_.-]+$' |
    sed 's/\./\\./g' | tr '\n' '|' | sed 's/|$//')

# Hosts-format lines, single-column domain lines, and custom domains are
# normalized in one pass.  This is deliberately not awk: busybox awk on this
# CPU is ~40x slower and its old suffix check dropped valid domains.
{
    cat "$WORK"/src.* 2>/dev/null |
        grep -E '^(0\.0\.0\.0|127\.0\.0\.1|::1|::|255\.255\.255\.255)[[:space:]]' |
        sed -E 's/^[^[:space:]]+[[:space:]]+//; s/#.*//'
    cat "$WORK"/src.* 2>/dev/null |
        grep -E '^[a-zA-Z0-9_.-]+$'
    [ -f "$WORK/config.custom" ] && sed -E 's/#.*//' "$WORK/config.custom"
} | tr -d '\r' | tr 'A-Z' 'a-z' | tr ' ' '\n' | tr '\t' '\n' |
    sed 's/\.$//' |
    grep -E '^[a-z0-9_.-]+\.[a-z0-9-]*[a-z][a-z0-9-]*$' |
    grep -Ev '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' |
    grep -Ev '^localhost\.localdomain$' |
    { if [ -n "$ALLOW_RE" ]; then grep -Ev "(^|\\.)($ALLOW_RE)$"; else cat; fi; } |
    sed 's/^/0.0.0.0 /' > "$WORK/hosts.v4.raw"

RAW_LINES=$(wc -l < "$WORK/hosts.v4.raw")
if [ "$RAW_LINES" -le 150000 ]; then
    if sort -u "$WORK/hosts.v4.raw" > "$WORK/hosts.v4.new" 2>/dev/null; then
        rm -f "$WORK/hosts.v4.raw"
    else
        mv "$WORK/hosts.v4.raw" "$WORK/hosts.v4.new"
    fi
else
    # Avoid sort's in-memory buffer on low-memory routers.  Duplicate hosts
    # entries are harmless; dnsmasq deduplicates them while loading.
    mv "$WORK/hosts.v4.raw" "$WORK/hosts.v4.new"
fi

LINES=$(wc -l < "$WORK/hosts.v4.new")
echo "domains: $LINES ($(($(date +%s) - T0))s)"
nvram set adblock_progress="$LINES domains"

MIN_LINES=1000
[ "$(nvram get adblock_presets)" = "0" ] && MIN_LINES=1
if [ "$LINES" -lt "$MIN_LINES" ]; then
    fail_update "update rejected: only $LINES domains"
fi
if [ "$LINES" -gt 500000 ]; then
    fail_update "update rejected: $LINES domains is too many"
fi

for d in example.com google.com github.com raw.githubusercontent.com apple.com microsoft.com whatsapp.com paypal.com; do
    if grep -qx "0.0.0.0 $d" "$WORK/hosts.v4.new"; then
        fail_update "update rejected: critical domain $d blocked"
    fi
done
chmod 644 "$WORK/hosts.v4.new"

# Build the matching IPv6 blocklist with sed (fast, no awk).
sed 's/^0\.0\.0\.0 /::1 /' "$WORK/hosts.v4.new" > "$WORK/hosts.v6.new" ||
    fail_update "update failed: IPv6 list error"
chmod 644 "$WORK/hosts.v6.new"

# Keep a compressed copy of the IPv4 list in NAND.
gzip -9 -c "$WORK/hosts.v4.new" > "$WORK/hosts.gz.new" ||
    fail_update "update failed: gzip error"
gzip -t "$WORK/hosts.gz.new" ||
    fail_update "update failed: gzip test error"

GZ_SIZE=$(wc -c < "$WORK/hosts.gz.new")
if [ "$GZ_SIZE" -gt 4000000 ]; then
    fail_update "update rejected: gzip is too large"
fi

OLD_SIZE=0
[ -f "$DIR/hosts" ] && OLD_SIZE=$(wc -c < "$DIR/hosts")
OLD_GZ=0
[ -f "$DIR/hosts.gz" ] && OLD_GZ=$(wc -c < "$DIR/hosts.gz")
FREE=$(df -k /etc | awk 'NR==2 {print $4 * 1024}')
AVAIL=$((FREE + OLD_SIZE + OLD_GZ))
PERSISTED=0
if [ "$AVAIL" -gt $((GZ_SIZE + 65536)) ]; then
    rm -f "$DIR/hosts" "$DIR/hosts.gz"
    if cp "$WORK/hosts.gz.new" "$DIR/hosts.gz"; then
        chmod 644 "$DIR/hosts.gz"
        PERSISTED=1
    else
        rm -f "$DIR/hosts.gz"
        [ -f "$WORK/hosts.gz.bak" ] && cp "$WORK/hosts.gz.bak" "$DIR/hosts.gz"
        logger -t adblock "could not save hosts.gz; previous list restored"
    fi
else
    logger -t adblock "not enough /etc space for hosts.gz ($GZ_SIZE > $AVAIL)"
fi

# Swap in the new live lists.
mv "$WORK/hosts.v4.new" "$WORK/hosts.v4"
mv "$WORK/hosts.v6.new" "$WORK/hosts.v6"
rm -f "$WORK/hosts.gz.new" "$WORK/hosts.gz.bak"

nvram set adblock_phase=applying
nvram set adblock_progress="$LINES domains, loading DNS"

QLOG_LINES=0
[ -f "$QLOG" ] && QLOG_LINES=$(wc -l < "$QLOG")

if [ "$(nvram get adblock_enable)" != "0" ]; then
    if [ "$(nvram get sw_mode)" = "3" ]; then
        if [ -s "$PID" ] && kill -0 "$(cat "$PID")" 2>/dev/null; then
            kill -HUP "$(cat "$PID")" || fail_update "update failed: DNS reload failed"
        else
            "$BIN/restart.sh" || fail_update "update failed: DNS restart failed"
        fi
    else
        if pidof dnsmasq >/dev/null 2>&1; then
            killall -SIGHUP dnsmasq || fail_update "update failed: DNS reload failed"
        else
            if [ -x /tmp/restart_dhcpd ]; then
                /tmp/restart_dhcpd || fail_update "update failed: DHCP/DNS restart failed"
            else
                killall dnsmasq 2>/dev/null
                sleep 1
                /usr/sbin/dnsmasq || fail_update "update failed: DNS start failed"
            fi
        fi
    fi

    # Wait until the new IPv4 hosts file has actually been read.  A large list
    # takes tens of seconds on this CPU; reporting success before that leaves
    # a window where the UI says "done" but blocking is not active yet.
    i=0
    while [ "$i" -lt 240 ]; do
        if tail -n +$((QLOG_LINES + 1)) "$QLOG" 2>/dev/null |
                grep -q "read $WORK/hosts.v4 - "; then
            break
        fi
        sleep 2
        i=$((i + 2))
    done

    # dnsmasq reports the number of unique names it actually loaded.  Use that
    # as the displayed domain count instead of the raw line count.
    DNS_LINES=$(tail -n +$((QLOG_LINES + 1)) "$QLOG" 2>/dev/null |
        sed -n "s|.*read $WORK/hosts.v4 - \([0-9][0-9]*\) names.*|\1|p" | tail -1)
    if [ -n "$DNS_LINES" ]; then
        LINES="$DNS_LINES"
    else
        echo "warning: DNS reload confirmation not seen within 240s"
    fi
fi

echo "saved: $PERSISTED ($(($(date +%s) - T0))s)"

# If settings changed while the update was running, the list we just built is
# from the snapshot.  Keep the dirty flag set so the UI asks for another run.
LIVE_HASH=$( { cat "$SOURCES"; echo '---'; cat "$DIR/custom.hosts"; echo '---'; cat "$DIR/custom.allow"; } | md5sum | cut -d' ' -f1)
if [ "$LIVE_HASH" = "$CONFIG_HASH" ] && [ "$PERSISTED" = "1" ]; then
    DIRTY=0
    STATUS="$LINES domains, $(date '+%Y-%m-%d %H:%M')"
elif [ "$PERSISTED" = "1" ]; then
    DIRTY=1
    STATUS="$LINES domains; settings changed, update again"
else
    DIRTY=1
    STATUS="$LINES domains (not saved), $(date '+%Y-%m-%d %H:%M')"
fi
nvram set adblock_status="$STATUS"
nvram set adblock_source_status="$SRC_STATUS"
nvram set adblock_last_success="$(date '+%Y-%m-%d %H:%M')"
nvram set adblock_last_attempt="$(date '+%Y-%m-%d %H:%M') ok"
nvram set adblock_applied_hash="$CONFIG_HASH"
nvram set adblock_config_dirty="$DIRTY"
nvram set adblock_phase=idle
nvram set adblock_progress=""
nvram commit
/sbin/mtd_storage.sh save >/dev/null 2>&1
echo "=== update finished: $LINES domains from $OK/$TOTAL sources ==="
logger -t adblock "updated: $LINES domains from $OK/$TOTAL sources"
