#!/bin/sh
LOG=/tmp/adblock-queries.log

if [ ! -s "$LOG" ]; then
    nvram set adblock_stats="No blocked queries logged yet"
    nvram commit
    exit 0
fi

TOTAL=$(grep -c -E ' is (0\.0\.0\.0|::1)$' "$LOG" 2>/dev/null)
TOP=$(grep -E ' is (0\.0\.0\.0|::1)$' "$LOG" 2>/dev/null | awk '{print $2}' | sort | uniq -c | sort -nr | head -10)

nvram set adblock_stats="Blocked queries in current window: $TOTAL
Top blocked domains:
$TOP"
nvram commit

# Reset the window; dnsmasq reopens the log with O_APPEND.
: > "$LOG"
