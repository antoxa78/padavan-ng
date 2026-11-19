#!/bin/sh
BIN=$(cd "$(dirname "$0")" && pwd)
DIR=/etc/storage/adblock
WORK=/tmp/adblock
SOURCES=$DIR/sources.conf
PID=/var/run/adblock-dnsmasq.pid
LOCK=$WORK/update.lock

mkdir -p "$WORK"
LOG=/tmp/adblock-update.log
: > "$LOG"
exec >> "$LOG" 2>&1
echo "=== $(date '+%Y-%m-%d %H:%M:%S') update start ==="
if [ -f "$LOCK" ] && kill -0 "$(cat "$LOCK")" 2>/dev/null; then
    logger -t adblock "update already running"
    exit 1
fi
echo $$ > "$LOCK"
trap 'rm -f "$LOCK"' EXIT

fail_update() {
    logger -t adblock "$1"
    echo "FAILED: $1"
    [ -n "$SRC_STATUS" ] && nvram set adblock_source_status="$SRC_STATUS"
    "$BIN/start.sh" >/dev/null 2>&1
    nvram set adblock_status="$1"
    nvram commit
    rm -f "$LOCK"
    exit 1
}

[ -f "$SOURCES" ] || : > "$SOURCES"
[ -s "$DIR/custom.allow" ] || echo '# no allowlist' > "$DIR/custom.allow"

rm -f "$WORK"/src.* "$WORK"/hosts.v4.new "$WORK"/hosts.v6.new "$WORK"/hosts.gz.new "$WORK"/hosts.gz.bak "$WORK"/hosts
SRC_STATUS=""
N=0
OK=0
while IFS= read -r url; do
    case "$url" in ''|'#'*) continue;; esac
    N=$((N + 1))
    if wget -q -T 30 -O "$WORK/src.$N" "$url"; then
        if [ "$(wc -c < "$WORK/src.$N")" -gt 1000 ]; then
            OK=$((OK + 1))
            SRC_LINES=$(wc -l < "$WORK/src.$N")
            SRC_STATUS="$SRC_STATUS$url ($SRC_LINES lines)
"
        else
            logger -t adblock "empty download: $url"
            rm -f "$WORK/src.$N"
        fi
    else
        logger -t adblock "download failed: $url"
        rm -f "$WORK/src.$N"
    fi
done < "$SOURCES"

echo "sources: $OK/$N downloaded"
if [ "$OK" -eq 0 ] && [ ! -s "$DIR/custom.hosts" ]; then
    fail_update "update failed: no sources and no custom domains"
fi

# Keep the previous gzip in /tmp as a rollback copy.
[ -f "$DIR/hosts.gz" ] && cp "$DIR/hosts.gz" "$WORK/hosts.gz.bak"

# Free the live lists before building new ones; dnsmasq keeps them in memory.
rm -f "$WORK/hosts.v4" "$WORK/hosts.v6"

# Normalize, apply the allowlist, then deduplicate (IPv4 list).
set -- "$DIR/custom.allow"
for f in "$WORK"/src.*; do
    [ -f "$f" ] && set -- "$@" "$f"
done
[ -f "$DIR/custom.hosts" ] && set -- "$@" "$DIR/custom.hosts"
if ! awk '
function clean(d) {
    gsub(/^[ \t]+/, "", d); gsub(/[ \t]+$/, "", d);
    d = tolower(d); sub(/\.$/, "", d);
    if (d == "") return "";
    if (d ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/) return "";
    if (d ~ /:/) return "";
    if (d ~ /^\./) return "";
    if (d == "localhost" || d == "localhost.localdomain" || d == "broadcasthost" || d == "local" || d ~ /^ip6-/) return "";
    if (d !~ /^[a-z0-9_.-]+$/) return "";
    return d;
}
function allowed(d, a) {
    if (d in allow) return 1;
    for (a in allow) {
        if (index(d, "." a) == length(d) - length(a)) return 1;
    }
    return 0;
}
NR==FNR {
    sub(/#.*/, "");
    gsub(/\r/, "");
    gsub(/^[ \t]+/, ""); gsub(/[ \t]+$/, "");
    n = split($0, a, /[ \t]+/);
    if (n == 0) next;
    d = (n > 1 ? a[n] : a[1]);
    d = tolower(d); sub(/\.$/, "", d);
    if (d != "" && d !~ /:/ && d !~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/) allow[d] = 1;
    next;
}
{
    sub(/#.*/, "");
    gsub(/\r/, "");
    gsub(/^[ \t]+/, ""); gsub(/[ \t]+$/, "");
    n = split($0, a, /[ \t]+/);
    if (n == 0) next;
    if (a[1] == "0.0.0.0" || a[1] == "127.0.0.1" || a[1] == "::1" || a[1] == "::" || a[1] == "255.255.255.255") {
        for (i = 2; i <= n; i++) { d = clean(a[i]); if (d != "" && !allowed(d)) print "0.0.0.0 " d; }
    } else if (n == 1) {
        d = clean(a[1]); if (d != "" && d ~ /\./ && !allowed(d)) print "0.0.0.0 " d;
    }
}' "$@" | sort -u > "$WORK/hosts.v4.new"; then
    fail_update "update failed: merge error"
fi
rm -f "$WORK"/src.*

LINES=$(wc -l < "$WORK/hosts.v4.new")
echo "domains: $LINES"
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

# Build the matching IPv6 blocklist.
if ! awk '{print "::1 " $2}' "$WORK/hosts.v4.new" > "$WORK/hosts.v6.new"; then
    fail_update "update failed: IPv6 list error"
fi
chmod 644 "$WORK/hosts.v6.new"

# Keep a compressed copy of the IPv4 list in NAND.
gzip -9 -c "$WORK/hosts.v4.new" > "$WORK/hosts.gz.new" || fail_update "update failed: gzip error"
gzip -t "$WORK/hosts.gz.new" || fail_update "update failed: gzip test error"

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

if [ "$(nvram get adblock_enable)" != "0" ]; then
    if [ "$(nvram get sw_mode)" = "3" ]; then
        if [ -s "$PID" ] && kill -0 "$(cat "$PID")" 2>/dev/null; then
            kill -HUP "$(cat "$PID")"
        else
            "$BIN/restart.sh"
        fi
    else
        if pidof dnsmasq >/dev/null 2>&1; then
            killall -SIGHUP dnsmasq
        else
            if [ -x /tmp/restart_dhcpd ]; then
                /tmp/restart_dhcpd
            else
                killall dnsmasq 2>/dev/null
                sleep 1
                /usr/sbin/dnsmasq
            fi
        fi
    fi
fi

echo "saved: $PERSISTED"
if [ "$PERSISTED" = "1" ]; then
    nvram set adblock_status="$LINES domains, $(date '+%Y-%m-%d %H:%M')"
else
    nvram set adblock_status="$LINES domains (not saved), $(date '+%Y-%m-%d %H:%M')"
fi
nvram set adblock_source_status="$SRC_STATUS"
nvram set adblock_last_success="$(date '+%Y-%m-%d %H:%M')"
nvram commit
/sbin/mtd_storage.sh save >/dev/null 2>&1
echo "=== update finished: $LINES domains from $OK/$N sources ==="
logger -t adblock "updated: $LINES domains from $OK/$N sources"
