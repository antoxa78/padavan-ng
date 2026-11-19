#!/bin/sh
R=$(tail -30 /tmp/adblock-update.log 2>/dev/null)
[ -n "$R" ] || R="No update log yet"
nvram set adblock_update_log="$R"
nvram commit
