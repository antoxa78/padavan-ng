#!/bin/sh
BIN=/usr/sbin/adblock
nvram set adblock_presets=127
nvram set adblock_extra_sources=""
nvram set adblock_custom="$(cat "$BIN/defaults/custom.hosts")"
nvram set adblock_allow="$(cat "$BIN/defaults/custom.allow")"
nvram set adblock_interval=weekly
nvram set adblock_enable=1
nvram commit
/tmp/adblock_apply.sh
