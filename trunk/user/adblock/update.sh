#!/bin/sh
BIN=$(cd "$(dirname "$0")" && pwd)
DIR=/etc/storage/adblock
WORK=/tmp/adblock
SOURCES=$DIR/sources.conf
PID=/var/run/adblock-dnsmasq.pid
LOCK=$WORK/update.lock

mkdir -p "$WORK"
if [ -f "$LOCK" ] && kill -0 "$(cat "$LOCK")" 2>/dev/null; then
    logger -t adblock "update already running"
    exit 1
fi
echo $$ > "$LOCK"
trap 'rm -f "$LOCK"' EXIT

[ -s "$SOURCES" ] || { logger -t adblock "missing $SOURCES"; exit 1; }

rm -f "$WORK"/src.* "$WORK"/hosts.v4.new "$WORK"/hosts.v6.new "$WORK"/hosts.gz.new "$WORK"/hosts
N=0
OK=0
while IFS= read -r url; do
    case "$url" in ''|'#'*) continue;; esac
    N=$((N + 1))
    if wget -q -T 30 -O "$WORK/src.$N" "$url"; then
        if [ "$(wc -c < "$WORK/src.$N")" -gt 1000 ]; then
            OK=$((OK + 1))
        else
            logger -t adblock "empty download: $url"
            rm -f "$WORK/src.$N"
        fi
    else
        logger -t adblock "download failed: $url"
        rm -f "$WORK/src.$N"
    fi
done < "$SOURCES"

if [ "$OK" -eq 0 ]; then
    logger -t adblock "update failed: no sources downloaded"
    exit 1
fi

# Free the live lists before building new ones; dnsmasq keeps them in memory.
rm -f "$WORK/hosts.v4" "$WORK/hosts.v6"

# Normalize hosts files and domain-only lists, then deduplicate (IPv4 list).
set -- "$WORK"/src.*
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
{
    sub(/#.*/, "");
    gsub(/\r/, "");
    gsub(/^[ \t]+/, ""); gsub(/[ \t]+$/, "");
    n = split($0, a, /[ \t]+/);
    if (n == 0) next;
    if (a[1] == "0.0.0.0" || a[1] == "127.0.0.1" || a[1] == "::1" || a[1] == "::" || a[1] == "255.255.255.255") {
        for (i = 2; i <= n; i++) { d = clean(a[i]); if (d != "") print "0.0.0.0 " d; }
    } else if (n == 1) {
        d = clean(a[1]); if (d != "" && d ~ /\./) print "0.0.0.0 " d;
    }
}' "$@" | sort -u > "$WORK/hosts.v4.new"; then
    logger -t adblock "merge failed"
    rm -f "$WORK/hosts.v4.new"
    exit 1
fi
rm -f "$WORK"/src.*

LINES=$(wc -l < "$WORK/hosts.v4.new")
if [ "$LINES" -lt 1000 ]; then
    logger -t adblock "update failed: only $LINES domains"
    rm -f "$WORK/hosts.v4.new"
    exit 1
fi
chmod 644 "$WORK/hosts.v4.new"

# Build the matching IPv6 blocklist.
if ! awk '{print "::1 " $2}' "$WORK/hosts.v4.new" > "$WORK/hosts.v6.new"; then
    logger -t adblock "could not build IPv6 list"
    rm -f "$WORK/hosts.v6.new"
    exit 1
fi
chmod 644 "$WORK/hosts.v6.new"

# Keep a compressed copy of the IPv4 list in NAND.
gzip -9 -c "$WORK/hosts.v4.new" > "$WORK/hosts.gz.new" || { logger -t adblock "gzip failed"; exit 1; }
gzip -t "$WORK/hosts.gz.new" || { logger -t adblock "gzip test failed"; rm -f "$WORK/hosts.gz.new"; exit 1; }

GZ_SIZE=$(wc -c < "$WORK/hosts.gz.new")
OLD_SIZE=0
[ -f "$DIR/hosts" ] && OLD_SIZE=$(wc -c < "$DIR/hosts")
OLD_GZ=0
[ -f "$DIR/hosts.gz" ] && OLD_GZ=$(wc -c < "$DIR/hosts.gz")
FREE=$(df -k /etc | awk 'NR==2 {print $4 * 1024}')
AVAIL=$((FREE + OLD_SIZE + OLD_GZ))
if [ "$AVAIL" -gt $((GZ_SIZE + 65536)) ]; then
    rm -f "$DIR/hosts" "$DIR/hosts.gz"
    if cp "$WORK/hosts.gz.new" "$DIR/hosts.gz"; then
        chmod 644 "$DIR/hosts.gz"
    else
        rm -f "$DIR/hosts.gz"
        logger -t adblock "could not save hosts.gz"
    fi
else
    logger -t adblock "not enough /etc space for hosts.gz ($GZ_SIZE > $AVAIL)"
fi

# Swap in the new live lists.
mv "$WORK/hosts.v4.new" "$WORK/hosts.v4"
mv "$WORK/hosts.v6.new" "$WORK/hosts.v6"
rm -f "$WORK/hosts.gz.new"

if [ "$(nvram get adblock_enable)" != "0" ]; then
    if [ -s "$PID" ] && kill -0 "$(cat "$PID")" 2>/dev/null; then
        kill -HUP "$(cat "$PID")"
    else
        "$BIN/restart.sh"
    fi
fi

nvram set adblock_status="$LINES domains, $(date '+%Y-%m-%d %H:%M')"
nvram commit
/sbin/mtd_storage.sh save >/dev/null 2>&1
logger -t adblock "updated: $LINES domains from $OK/$N sources"
