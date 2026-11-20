#!/bin/sh
LOCK=/tmp/adblock/update.lock
if [ -f "$LOCK" ] && kill -0 "$(cat "$LOCK")" 2>/dev/null; then
    # Leave the running update's phase/progress untouched; only report that
    # the duplicate request was ignored.
    nvram set adblock_status="update already running"
    nvram commit
    exit 0
fi
/usr/sbin/adblock/save.sh >/dev/null 2>&1
nvram set adblock_status="updating..."
nvram set adblock_phase=downloading
nvram set adblock_progress="starting"
nvram set adblock_last_attempt="$(date '+%Y-%m-%d %H:%M') starting"
nvram commit
/usr/sbin/adblock/update.sh >/dev/null 2>&1 &
