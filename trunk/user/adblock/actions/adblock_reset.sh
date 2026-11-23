#!/bin/sh
BIN=/usr/sbin/adblock
WILD=$(sed -n 's|^address=/\([^/]*\)/0\.0\.0\.0$|\1|p' "$BIN/defaults/wildcard.conf" 2>/dev/null | awk 'NF && !seen[$0]++')
nvram set adblock_presets=52
nvram set adblock_extra_sources=""
nvram set adblock_custom="$(cat "$BIN/defaults/custom.hosts")"
nvram set adblock_allow="$(cat "$BIN/defaults/custom.allow")"
nvram set adblock_wildcard="$WILD"
nvram set adblock_doh_block=1
nvram set adblock_rebind=0
nvram set adblock_interval=weekly
nvram set adblock_update_hour=4
nvram set adblock_update_min=15
nvram set adblock_enable=1
nvram commit
/usr/sbin/adblock/save.sh
