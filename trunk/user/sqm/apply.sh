#!/bin/sh
# Apply SQM/QoS rules from NVRAM settings.
#
# Upload shaping uses HTB + fq_codel on the WAN interface.  Download shaping
# redirects WAN ingress to ifb0 and shapes it with a second HTB tree.  Optional
# per-client limits are HTB classes matched by IPv4 address.

BIN=/usr/sbin/sqm
. "$BIN/common.sh"

LOCK=/tmp/sqm.lock
if ! mkdir "$LOCK" 2>/dev/null; then
	# Wait for a concurrent apply (for example the firewall hook) to finish,
	# then re-read NVRAM so the newest settings win.
	i=0
	while [ "$i" -lt 10 ]; do
		PID=$(cat "$LOCK/pid" 2>/dev/null)
		if [ -z "$PID" ] || ! kill -0 "$PID" 2>/dev/null; then
			break
		fi
		sleep 1
		i=$((i + 1))
	done
	PID=$(cat "$LOCK/pid" 2>/dev/null)
	if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
		exit 0
	fi
	rm -rf "$LOCK"
	mkdir "$LOCK" 2>/dev/null || exit 1
fi
echo $$ > "$LOCK/pid"
trap 'rm -rf "$LOCK"' EXIT

WAN=""
RULES=0
WARN=""

fail() {
	"$BIN/stop.sh" --quiet
	nvram set sqm_status="error"
	nvram set sqm_summary="SQM is not applied"
	nvram set sqm_last_error="$1"
	nvram set sqm_active_iface="$WAN"
	nvram set sqm_rule_count=0
	nvram commit
	logger -t sqm "error: $1"
	exit 1
}

if [ "$(nvram get sqm_enable)" != "1" ]; then
	"$BIN/stop.sh"
	exit 0
fi

if [ "$(nvram get sw_mode)" = "3" ]; then
	"$BIN/stop.sh" --quiet
	nvram set sqm_status="disabled"
	nvram set sqm_summary="SQM is not available in AP mode"
	nvram set sqm_last_error=""
	nvram set sqm_active_iface=""
	nvram set sqm_rule_count=0
	nvram commit
	exit 0
fi

UPM=$(sqm_parse_mbps "$(nvram get sqm_upload_mbps)")
DOWNM=$(sqm_parse_mbps "$(nvram get sqm_download_mbps)")
OVERHEAD=$(sqm_nvram_int sqm_overhead 95 50 100)
DL_SHAPE=$(sqm_nvram_int sqm_download_shape 1 0 1)
CLIENTS=$(nvram get sqm_clients)

UP_KBPS=$(sqm_kbps "$UPM" "$OVERHEAD")
DOWN_KBPS=$(sqm_kbps "$DOWNM" "$OVERHEAD")
[ "$UP_KBPS" -lt 100 ] && UP_KBPS=0
[ "$DOWN_KBPS" -lt 100 ] && DOWN_KBPS=0

if [ "$UP_KBPS" = "0" ] && [ "$DOWN_KBPS" = "0" ]; then
	"$BIN/stop.sh" --quiet
	nvram set sqm_status="not configured"
	nvram set sqm_summary="Set the WAN upload or download speed"
	nvram set sqm_last_error=""
	nvram set sqm_active_iface=""
	nvram set sqm_rule_count=0
	nvram commit
	exit 0
fi

command -v tc >/dev/null 2>&1 || fail "tc is not installed in this firmware"

WAN=$(sqm_wan_iface)
if [ -z "$WAN" ] || [ ! -d "/sys/class/net/$WAN" ]; then
	WAN=""
	"$BIN/stop.sh" --quiet
	nvram set sqm_status="waiting for WAN"
	nvram set sqm_summary="WAN interface is not available yet"
	nvram set sqm_last_error=""
	nvram set sqm_active_iface=""
	nvram set sqm_rule_count=0
	nvram commit
	exit 0
fi

"$BIN/stop.sh" --quiet

for m in sch_htb sch_fq_codel sch_ingress cls_u32 act_mirred ifb; do
	modprobe "$m" 2>/dev/null
done

setup_root() {
	local dev="$1"
	local root="$2"
	local rate="$3"

	tc qdisc del dev "$dev" root 2>/dev/null
	tc qdisc add dev "$dev" root handle "${root}:" htb default 30 || return 1
	tc class add dev "$dev" parent "${root}:" classid "${root}:1" htb \
		rate "${rate}kbit" ceil "${rate}kbit" || return 1
	tc class add dev "$dev" parent "${root}:1" classid "${root}:30" htb \
		rate 8kbit ceil "${rate}kbit" prio 2 || return 1
	tc qdisc add dev "$dev" parent "${root}:30" fq_codel \
		limit 1024 target 5ms interval 100ms || return 1
	return 0
}

setup_client() {
	local dev="$1"
	local root="$2"
	local id="$3"
	local mark="$4"
	local cap="$5"

	tc class add dev "$dev" parent "${root}:1" classid "${root}:${id}" htb \
		rate 8kbit ceil "${cap}kbit" prio 1 || return 1
	tc qdisc add dev "$dev" parent "${root}:${id}" fq_codel \
		limit 512 target 5ms interval 100ms 2>/dev/null || true
	tc filter add dev "$dev" parent "${root}:" protocol ip handle "$mark" fw \
		flowid "${root}:${id}" || return 1
	return 0
}

valid_ipv4() {
	printf '%s\n' "$1" | awk -F. '
		NF == 4 &&
		$1 ~ /^(0|[1-9][0-9]{0,2})$/ && $2 ~ /^(0|[1-9][0-9]{0,2})$/ &&
		$3 ~ /^(0|[1-9][0-9]{0,2})$/ && $4 ~ /^(0|[1-9][0-9]{0,2})$/ &&
		$1 + 0 >= 1 && $1 + 0 <= 255 && $2 + 0 >= 0 && $2 + 0 <= 255 &&
		$3 + 0 >= 0 && $3 + 0 <= 255 && $4 + 0 >= 0 && $4 + 0 <= 255 { ok = 1 }
		END { exit ok ? 0 : 1 }'
}

apply_clients() {
	local dev="$1"
	local root="$2"
	local rate="$3"
	local idx=100
	local count=0
	local cip cup cap mark

	[ -n "$CLIENTS" ] || return 0

	modprobe iptable_mangle 2>/dev/null
	modprobe xt_MARK 2>/dev/null
	modprobe cls_fw 2>/dev/null
	iptables -t mangle -N SQM_MARK 2>/dev/null
	iptables -t mangle -F SQM_MARK 2>/dev/null || return 0
	iptables -t mangle -C FORWARD -j SQM_MARK 2>/dev/null || \
		iptables -t mangle -I FORWARD 1 -j SQM_MARK 2>/dev/null
	[ $? -eq 0 ] || return 0

	printf '%s\n' "$CLIENTS" > "/tmp/sqm.clients.$$"

	while IFS='|' read -r cip cup _; do
		cip=$(printf '%s' "$cip" | tr -d ' \t\r')
		cup=$(printf '%s' "$cup" | tr -d ' \t\r')
		[ -n "$cip" ] || continue
		valid_ipv4 "$cip" || continue

		cup=$(sqm_parse_mbps "$cup")
		cap=$(sqm_kbps "$cup" 100)
		[ "$cap" -ge 100 ] || continue
		[ "$cap" -gt "$rate" ] && cap="$rate"
		[ "$idx" -le 199 ] || break

		# Keep the mark in the high 16 bits so other fwmark users are not
		# clobbered by the per-client rules.
		mark="$((0x51000000 + (idx << 16)))/0xffff0000"
		iptables -t mangle -A SQM_MARK -s "$cip/32" \
			-j MARK --set-mark "$mark" 2>/dev/null || continue

		if setup_client "$dev" "$root" "$idx" "$mark" "$cap"; then
			idx=$((idx + 1))
			count=$((count + 1))
		else
			iptables -t mangle -D SQM_MARK -s "$cip/32" \
				-j MARK --set-mark "$mark" 2>/dev/null
		fi
	done < "/tmp/sqm.clients.$$"
	rm -f "/tmp/sqm.clients.$$"

	RULES=$((RULES + count))
}

if [ "$UP_KBPS" -gt 0 ]; then
	setup_root "$WAN" 1 "$UP_KBPS" || fail "Cannot create the upload queue"
	RULES=$((RULES + 1))
	apply_clients "$WAN" 1 "$UP_KBPS"
fi

DOWN_ACTIVE_KBPS=0
if [ "$DL_SHAPE" = "1" ] && [ "$DOWN_KBPS" -gt 0 ]; then
	DL_OK=1
	if ! sqm_ifb_ready; then
		ip link add ifb0 type ifb 2>/dev/null || DL_OK=0
	fi
	[ "$DL_OK" = "1" ] && { ip link set ifb0 up 2>/dev/null || DL_OK=0; }

	if [ "$DL_OK" = "1" ]; then
		tc qdisc del dev "$WAN" handle ffff: ingress 2>/dev/null
		tc qdisc add dev "$WAN" handle ffff: ingress 2>/dev/null || DL_OK=0
	fi
	if [ "$DL_OK" = "1" ]; then
		tc filter add dev "$WAN" parent ffff: protocol ip prio 1 u32 \
			match u32 0 0 action mirred egress redirect dev ifb0 \
			2>/dev/null || DL_OK=0
	fi
	if [ "$DL_OK" = "1" ]; then
		# IPv6 is best-effort; older kernels may reject the filter.
		tc filter add dev "$WAN" parent ffff: protocol ipv6 prio 2 u32 \
			match u32 0 0 action mirred egress redirect dev ifb0 \
			2>/dev/null || true
	fi
	if [ "$DL_OK" = "1" ]; then
		setup_root ifb0 2 "$DOWN_KBPS" || DL_OK=0
	fi

	if [ "$DL_OK" = "1" ]; then
		RULES=$((RULES + 1))
		DOWN_ACTIVE_KBPS=$DOWN_KBPS
	else
		tc qdisc del dev "$WAN" handle ffff: ingress 2>/dev/null
		tc qdisc del dev ifb0 root 2>/dev/null
		WARN="download shaping unavailable, upload only"
	fi
fi

if [ "$UP_KBPS" -gt 0 ]; then
	tc qdisc show dev "$WAN" 2>/dev/null | grep -q 'htb' || \
		fail "Upload queue was not created"
fi
if [ "$DL_SHAPE" = "1" ] && [ "$DOWN_KBPS" -gt 0 ] && [ -z "$WARN" ]; then
	tc qdisc show dev ifb0 2>/dev/null | grep -q 'htb' || \
		fail "Download queue was not created"
fi

UP_MBPS=$(awk -v k="$UP_KBPS" 'BEGIN { printf "%.1f", k / 1000 }')
DOWN_MBPS=$(awk -v k="$DOWN_ACTIVE_KBPS" 'BEGIN { printf "%.1f", k / 1000 }')
LINK_SPEED=$(cat "/sys/class/net/$WAN/speed" 2>/dev/null)
[ -z "$LINK_SPEED" ] && LINK_SPEED="unknown"

APPLIED=1
if [ -n "$WARN" ]; then
	if [ "$UP_KBPS" -gt 0 ]; then
		nvram set sqm_status="active (upload only)"
		nvram set sqm_summary="Upload ${UP_MBPS} Mbit/s on ${WAN}; ${WARN}"
	else
		APPLIED=0
		nvram set sqm_status="error"
		nvram set sqm_summary="SQM is not applied"
		nvram set sqm_last_error="$WARN"
	fi
else
	SUMMARY="Upload ${UP_MBPS} / Download ${DOWN_MBPS} Mbit/s on ${WAN}"
	[ "$UP_KBPS" -eq 0 ] && SUMMARY="Download ${DOWN_MBPS} Mbit/s on ${WAN}"
	[ "$DOWN_ACTIVE_KBPS" -eq 0 ] && SUMMARY="Upload ${UP_MBPS} Mbit/s on ${WAN}"
	nvram set sqm_status="active"
	nvram set sqm_summary="$SUMMARY"
fi
if [ "$APPLIED" = "1" ]; then
	nvram set sqm_last_error=""
	nvram set sqm_applied="$(date '+%Y-%m-%d %H:%M:%S')"
fi
nvram set sqm_active_iface="$WAN"
nvram set sqm_link_speed="$LINK_SPEED"
nvram set sqm_rule_count="$RULES"
nvram commit

if [ "$APPLIED" = "1" ]; then
	logger -t sqm "applied on $WAN (upload ${UP_MBPS} Mbit/s, download ${DOWN_MBPS} Mbit/s, ${RULES} rules)"
else
	logger -t sqm "error: $WARN"
fi
exit 0
