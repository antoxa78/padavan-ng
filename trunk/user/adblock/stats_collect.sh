#!/bin/sh
# Aggregate blocked-query counts into a small persistent daily table.
# The live dnsmasq log is truncated after each pass; the table is kept in
# /tmp and copied to /etc/storage every 15 minutes (or on manual refresh).
BIN=$(cd "$(dirname "$0")" && pwd)
DIR=/etc/storage/adblock
WORK=/tmp/adblock
LOG=/tmp/adblock-queries.log
PERSIST=$DIR/stats/daily.tsv
RAM=$WORK/daily.tsv
LOCK=$WORK/stats.lock
SYNC=0
[ "$1" = "--sync" ] && SYNC=1

mkdir -p "$DIR/stats" "$WORK"
[ -f "$PERSIST" ] || : > "$PERSIST"
[ -f "$RAM" ] || cp "$PERSIST" "$RAM" 2>/dev/null || : > "$RAM"

# Do not truncate the query log while update.sh is waiting for the dnsmasq
# reload confirmation; the next watchdog pass will collect these lines.
if [ -f "$WORK/update.lock" ] && kill -0 "$(cat "$WORK/update.lock")" 2>/dev/null; then
    exit 0
fi

if [ -f "$LOCK" ] && kill -0 "$(cat "$LOCK")" 2>/dev/null; then
    exit 0
fi
echo $$ > "$LOCK"
trap 'rm -f "$LOCK"' EXIT

TODAY=$(date '+%Y-%m-%d')
MONTH=$(date '+%Y-%m')
TOP=""

if [ -s "$LOG" ]; then
    BLOCKED=$(grep -cE ' is (0\.0\.0\.0|::1)$' "$LOG" 2>/dev/null)
    TOTAL=$(grep -c 'query\[' "$LOG" 2>/dev/null)
    [ -z "$BLOCKED" ] && BLOCKED=0
    [ -z "$TOTAL" ] && TOTAL=0
    TOP=$(grep -E ' is (0\.0\.0\.0|::1)$' "$LOG" 2>/dev/null |
        sed -E 's/.* ([^ ]+) is (0\.0\.0\.0|::1)$/\1/' |
        sort | uniq -c | sort -nr | head -10)

    if [ "$TOTAL" -gt 0 ] || [ "$BLOCKED" -gt 0 ]; then
        awk -v d="$TODAY" -v b="$BLOCKED" -v t="$TOTAL" '
            BEGIN { FS=OFS="\t"; found=0 }
            $1==d { $2+=b; $3+=t; found=1 }
            { print }
            END { if (!found) print d,b,t }
        ' "$RAM" | tail -n 400 > "$RAM.tmp"
    fi
    # If an update started while we were parsing, leave the log intact for the
    # next pass instead of truncating it under update.sh's reload check.
    if [ -f "$WORK/update.lock" ] && kill -0 "$(cat "$WORK/update.lock")" 2>/dev/null; then
        rm -f "$RAM.tmp"
        exit 0
    fi
    [ -f "$RAM.tmp" ] && mv "$RAM.tmp" "$RAM"
    : > "$LOG"
fi

TODAY_BLOCKED=$(awk -F'\t' -v d="$TODAY" '$1==d {s+=$2} END{print s+0}' "$RAM")
TODAY_TOTAL=$(awk -F'\t' -v d="$TODAY" '$1==d {s+=$3} END{print s+0}' "$RAM")
MONTH_BLOCKED=$(awk -F'\t' -v m="$MONTH" 'index($1,m)==1 {s+=$2} END{print s+0}' "$RAM")
ALL_BLOCKED=$(awk -F'\t' '{s+=$2} END{print s+0}' "$RAM")
RATE=0
[ "$TODAY_TOTAL" -gt 0 ] && RATE=$((TODAY_BLOCKED * 100 / TODAY_TOTAL))

nvram set adblock_stats_short="Blocked today: $TODAY_BLOCKED ($RATE%) · this month: $MONTH_BLOCKED"
nvram set adblock_stats="Blocked queries
  today: $TODAY_BLOCKED of $TODAY_TOTAL ($RATE%)
  this month: $MONTH_BLOCKED
  all time: $ALL_BLOCKED

Top blocked domains (last window):
$TOP"

# Persist the daily table every 15 minutes, or immediately on manual refresh.
NOW=$(date +%s)
LAST=0
[ -f "$WORK/stats.sync" ] && LAST=$(cat "$WORK/stats.sync" 2>/dev/null)
if [ "$SYNC" = "1" ] || [ $((NOW - LAST)) -ge 900 ]; then
    cp "$RAM" "$PERSIST" 2>/dev/null && echo "$NOW" > "$WORK/stats.sync"
    [ "$SYNC" = "1" ] && /sbin/mtd_storage.sh save >/dev/null 2>&1
fi
