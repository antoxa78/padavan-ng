#!/bin/sh
# Build the health dashboard and the recent-blocked list for the Diagnostics page.
DIR=/etc/storage/adblock
WORK=/tmp/adblock
RECENT=$WORK/recent.tsv

mkdir -p "$WORK"
[ -f "$RECENT" ] || : > "$RECENT"

NOW=$(date +%s)
DOMAINS=$(grep -c '^0\.0\.0\.0 ' "$WORK/hosts.v4" 2>/dev/null)
[ -z "$DOMAINS" ] && DOMAINS=0
if [ "$DOMAINS" -eq 0 ] && [ -s "$DIR/hosts.gz" ]; then
    DOMAINS=$(gzip -dc "$DIR/hosts.gz" 2>/dev/null | grep -c '^0\.0\.0\.0 ')
    [ -z "$DOMAINS" ] && DOMAINS=0
fi

if [ "$(nvram get sw_mode)" = "3" ]; then
    if [ -s /var/run/adblock-dnsmasq.pid ] &&
            kill -0 "$(cat /var/run/adblock-dnsmasq.pid)" 2>/dev/null; then
        RESOLVER="running"
    else
        RESOLVER="stopped"
    fi
else
    if pidof dnsmasq >/dev/null 2>&1; then
        RESOLVER="running"
    else
        RESOLVER="stopped"
    fi
fi

T0=$(cut -d' ' -f1 /proc/uptime)
DNS_STATE="failed"
i=0
while [ "$i" -lt 2 ]; do
    if timeout 5 nslookup example.com 127.0.0.1 >/dev/null 2>&1; then
        DNS_STATE="ok"
        break
    fi
    i=$((i + 1))
    [ "$i" -lt 2 ] && sleep 2
done
T1=$(cut -d' ' -f1 /proc/uptime)
DNS_MS=$(awk -v a="$T0" -v b="$T1" 'BEGIN { printf "%.0f", (b-a)*1000 }')

GW=$(ip route 2>/dev/null | awk '/^default / {
    for (i = 2; i <= NF; i++)
        if ($i == "via") { print $(i + 1); exit }
}')
if [ -n "$GW" ]; then
    PING=$(ping -c 2 -W 1 -q "$GW" 2>/dev/null |
        sed -n 's|.*min/avg/max = [^/]*/\([^/]*\)/.*|\1|p')
    [ -z "$PING" ] && PING="unreachable"
else
    GW="none"
    PING="n/a"
fi
case "$PING" in
    *[0-9]*) PING_TEXT="$PING ms";;
    *)       PING_TEXT="$PING";;
esac

MEM=$(awk '/^MemTotal:/ { t=$2 } /^MemFree:/ { f=$2 }
    END { printf "%.0f MB free / %.0f MB", f/1024, t/1024 }' /proc/meminfo)
LOAD=$(cut -d' ' -f1-3 /proc/loadavg)
UP=$(cut -d. -f1 /proc/uptime)
D=$((UP / 86400))
H=$(((UP % 86400) / 3600))
M=$(((UP % 3600) / 60))
UPTIME="${D}d ${H}h ${M}m"
TMPFREE=$(df -k /tmp 2>/dev/null | awk 'NR == 2 { printf "%.0f MB", $4/1024 }')

PAUSE=$(nvram get adblock_pause_until)
case "$PAUSE" in ''|*[!0-9]*) PAUSE=0;; esac
if [ "$(nvram get adblock_enable)" = "0" ]; then
    PAUSE_STATE="disabled"
elif [ "$PAUSE" -gt "$NOW" ] 2>/dev/null; then
    PAUSE_STATE="paused"
else
    PAUSE_STATE="active"
fi

BUSY=0
BUSY_REASON="Adblock is still starting; the page will refresh automatically."
for L in start.lock update.lock; do
    if [ -f "$WORK/$L" ] && kill -0 "$(cat "$WORK/$L")" 2>/dev/null; then
        BUSY=1
        [ "$L" = "update.lock" ] && BUSY_REASON="An update is in progress; health will refresh when it finishes."
    fi
done
UPTIME_SEC=$(cut -d. -f1 /proc/uptime 2>/dev/null)
case "$UPTIME_SEC" in ''|*[!0-9]*) UPTIME_SEC=0;; esac

REASON=""
if [ "$(nvram get adblock_enable)" != "0" ] &&
        { [ "$RESOLVER" != "running" ] || [ "$DNS_STATE" != "ok" ]; } &&
        { [ "$BUSY" = "1" ] || [ "$UPTIME_SEC" -lt 180 ]; }; then
    STATE="starting"
    REASON="$BUSY_REASON"
elif [ "$RESOLVER" != "running" ]; then
    STATE="error"
    REASON="The DNS resolver is not running. Check the Adblock service and resolver status."
elif [ "$DNS_STATE" != "ok" ]; then
    STATE="warn"
    REASON="The resolver is running, but the local DNS test failed. Check the upstream DNS and internet connection."
else
    STATE="ok"
fi

HEALTH="Resolver|$RESOLVER
DNS query|$DNS_MS ms ($DNS_STATE)
Gateway|$GW
Gateway latency|$PING_TEXT
Blocklist|$DOMAINS domains
Filtering|$PAUSE_STATE
Memory|$MEM
Load average|$LOAD
Uptime|$UPTIME
/tmp free|$TMPFREE
Blocked queries|$(nvram get adblock_stats_short)
Last update|$(nvram get adblock_last_success)"
nvram set adblock_health="$HEALTH"
nvram set adblock_health_state="$STATE"
nvram set adblock_health_reason="$REASON"

# Recent blocked domains, excluding allowlisted names plus wildcard and DoH
# blocks (the Allow button can only remove hosts-list entries).
ALLOW_TMP=$WORK/allow.tmp
WILD_TMP=$WORK/wild.tmp
grep -v '^[[:space:]]*#' "$DIR/custom.allow" 2>/dev/null |
    tr -d '\r' | tr 'A-Z' 'a-z' | sed '/^[[:space:]]*$/d' > "$ALLOW_TMP"
sed -n 's|^address=/\([^/]*\)/0\.0\.0\.0$|\1|p' \
    "$DIR/wildcard.conf" "$DIR/doh.conf" 2>/dev/null |
    tr -d '\r' | sort -u > "$WILD_TMP"

RECENT_OUT=$(awk -F'\t' -v now="$NOW" '
    FILENAME == ARGV[1] { allow[$0] = 1; next }
    FILENAME == ARGV[2] { wild[$0] = 1; next }
    {
        d = $2
        skip = 0
        for (a in allow)
            if (d == a || substr(d, length(d) - length(a)) == "." a) { skip = 1; break }
        if (skip) next
        for (w in wild)
            if (d == w || substr(d, length(d) - length(w)) == "." w) { skip = 1; break }
        if (skip) next
        count[d]++
        last[d] = $1
    }
    END {
        for (d in count)
            printf "%d|%s|%d\n", count[d], d, now - last[d]
    }
' "$ALLOW_TMP" "$WILD_TMP" "$RECENT" 2>/dev/null |
    sort -nr | head -25)
nvram set adblock_recent="$RECENT_OUT"

rm -f "$ALLOW_TMP" "$WILD_TMP"
