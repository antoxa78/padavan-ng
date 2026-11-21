#!/bin/sh
# Shared helpers for the SQM scripts.

PATH=/bin:/sbin:/usr/bin:/usr/sbin
export PATH
SQM_BIN=/usr/sbin/sqm

# Read an integer NVRAM value with a default and range clamp.
sqm_nvram_int() {
	local v
	v=$(nvram get "$1")
	case "$v" in
		''|*[!0-9]*) v="$2" ;;
	esac
	v=$(printf '%s' "$v" | sed 's/^0*//')
	[ -z "$v" ] && v=0
	[ "$v" -lt "$3" ] && v="$3"
	[ "$v" -gt "$4" ] && v="$4"
	echo "$v"
}

# Accept a decimal Mbps value and return a normalized number.
sqm_parse_mbps() {
	awk -v v="$1" '
		BEGIN {
			if (v !~ /^[0-9]+(\.[0-9]+)?$/)
				v = 0
			v = v + 0
			if (v < 0)
				v = 0
			if (v > 10000)
				v = 10000
			printf "%.3f", v
		}'
}

# Print the active WAN interface name, if one can be found.
sqm_wan_iface() {
	local w
	if [ -n "$SQM_WAN_IFACE" ] && [ -d "/sys/class/net/$SQM_WAN_IFACE" ]; then
		echo "$SQM_WAN_IFACE"
		return 0
	fi

	w=$(nvram get sqm_active_iface)
	if [ -n "$w" ] && [ -d "/sys/class/net/$w" ]; then
		echo "$w"
		return 0
	fi

	# Prefer the real WAN interface over the default route: with a VPN client
	# the default route points at tun0/wg0 while SQM still belongs on the WAN.
	w=$(nvram get wan0_ifname_t)
	[ -z "$w" ] && w=$(nvram get wan_ifname)
	if [ -n "$w" ] && [ -d "/sys/class/net/$w" ]; then
		echo "$w"
		return 0
	fi

	w=$(ip route 2>/dev/null | awk '/^default[ \t]/ {
		for (i = 1; i <= NF; i++)
			if ($i == "dev") {
				print $(i + 1)
				exit
			}
	}')
	[ -n "$w" ] && echo "$w"
}

# Return 0 when the IFB module/device is available.
sqm_ifb_ready() {
	[ -d /sys/class/net/ifb0 ] && return 0
	modprobe ifb 2>/dev/null
	[ -d /sys/class/net/ifb0 ] && return 0
	return 1
}

sqm_kbps() {
	awk -v m="$1" -v o="$2" 'BEGIN { printf "%d", m * 1000 * o / 100 }'
}
