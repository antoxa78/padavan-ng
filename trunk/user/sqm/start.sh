#!/bin/sh
# Start SQM/QoS, seed first-boot NVRAM defaults and publish the UI action.

BIN=/usr/sbin/sqm
. "$BIN/common.sh"

for a in sqm_save.sh sqm_stop.sh; do
	if [ -f "$BIN/actions/$a" ]; then
		cp "$BIN/actions/$a" "/tmp/$a.new" && mv "/tmp/$a.new" "/tmp/$a"
		chmod 755 "/tmp/$a"
	fi
done

CHANGED=0
set_default() {
	# $1 name, $2 value
	if [ -z "$(nvram get "$1")" ]; then
		nvram set "$1=$2"
		CHANGED=1
	fi
}

set_default sqm_enable 0
set_default sqm_upload_mbps 0
set_default sqm_download_mbps 0
set_default sqm_download_shape 1
set_default sqm_overhead 95
set_default sqm_status disabled
set_default sqm_summary "SQM is disabled"
set_default sqm_rule_count 0
[ "$CHANGED" = "1" ] && nvram commit

if [ "$(nvram get sqm_enable)" = "1" ]; then
	"$BIN/apply.sh"
else
	"$BIN/stop.sh"
fi
