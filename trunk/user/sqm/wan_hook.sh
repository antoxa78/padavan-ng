#!/bin/sh
# Re-apply SQM when the WAN interface goes up or down.

BIN=/usr/sbin/sqm
. "$BIN/common.sh"

case "$1" in
	up)
		[ "$(nvram get sqm_enable)" = "1" ] && \
			SQM_WAN_IFACE="$2" "$BIN/apply.sh"
		;;
	down)
		"$BIN/stop.sh" --quiet
		if [ "$(nvram get sqm_enable)" = "1" ]; then
			nvram set sqm_status="waiting for WAN"
			nvram set sqm_summary="WAN interface is down"
			nvram set sqm_last_error=""
			nvram set sqm_active_iface=""
			nvram set sqm_rule_count=0
			nvram commit
		fi
		;;
	firewall)
		# The mangle table is rebuilt on firewall restarts; restore marks.
		[ "$(nvram get sqm_enable)" = "1" ] && "$BIN/apply.sh"
		;;
esac
