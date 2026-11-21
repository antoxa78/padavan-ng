#!/bin/sh
# Remove SQM/QoS shaping rules.
# --quiet keeps the current status (used when apply.sh replaces the rules).

BIN=/usr/sbin/sqm
. "$BIN/common.sh"

QUIET=0
[ "$1" = "--quiet" ] && QUIET=1

for DEV in "$(nvram get sqm_active_iface)" "$(sqm_wan_iface)"; do
	[ -n "$DEV" ] || continue
	[ -d "/sys/class/net/$DEV" ] || continue
	tc qdisc del dev "$DEV" root 2>/dev/null
	tc qdisc del dev "$DEV" handle ffff: ingress 2>/dev/null
done

if [ -d /sys/class/net/ifb0 ]; then
	tc qdisc del dev ifb0 root 2>/dev/null
	ip link set ifb0 down 2>/dev/null
fi

# Remove per-client packet marks installed by apply.sh.  Do not load the
# mangle table just to clean up a stopped/disabled SQM.
if grep -q '^mangle$' /proc/net/ip_tables_names 2>/dev/null; then
	iptables -t mangle -D FORWARD -j SQM_MARK 2>/dev/null
	iptables -t mangle -F SQM_MARK 2>/dev/null
	iptables -t mangle -X SQM_MARK 2>/dev/null
fi

if [ "$QUIET" = "0" ]; then
	NEED_COMMIT=0
	[ "$(nvram get sqm_status)" != "disabled" ] && NEED_COMMIT=1
	[ "$(nvram get sqm_summary)" != "SQM is disabled" ] && NEED_COMMIT=1
	[ -n "$(nvram get sqm_active_iface)" ] && NEED_COMMIT=1
	[ -n "$(nvram get sqm_last_error)" ] && NEED_COMMIT=1
	[ -n "$(nvram get sqm_applied)" ] && NEED_COMMIT=1
	[ -n "$(nvram get sqm_link_speed)" ] && NEED_COMMIT=1
	[ "$(nvram get sqm_rule_count)" != "0" ] && NEED_COMMIT=1
	if [ "$NEED_COMMIT" = "1" ]; then
		nvram set sqm_status="disabled"
		nvram set sqm_summary="SQM is disabled"
		nvram set sqm_last_error=""
		nvram set sqm_active_iface=""
		nvram set sqm_applied=""
		nvram set sqm_link_speed=""
		nvram set sqm_rule_count=0
		nvram commit
		logger -t sqm "stopped"
	fi
fi

exit 0
