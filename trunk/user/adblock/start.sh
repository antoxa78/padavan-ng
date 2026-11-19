#!/bin/sh
BIN=$(cd "$(dirname "$0")" && pwd)
DIR=/etc/storage/adblock
WORK=/tmp/adblock
PID=/var/run/adblock-dnsmasq.pid

mkdir -p "$DIR" "$WORK"
[ -f "$DIR/sources.conf" ] || cp "$BIN/defaults/sources.conf" "$DIR/sources.conf"
[ -f "$DIR/custom.hosts" ] || cp "$BIN/defaults/custom.hosts" "$DIR/custom.hosts"
[ -f "$DIR/custom.allow" ] || cp "$BIN/defaults/custom.allow" "$DIR/custom.allow"
[ -f "$DIR/wildcard.conf" ] || cp "$BIN/defaults/wildcard.conf" "$DIR/wildcard.conf"
[ -f "$DIR/dnsmasq.conf" ] || cp "$BIN/defaults/dnsmasq.conf" "$DIR/dnsmasq.conf"

# Action scripts used by the web UI.
for a in adblock_apply.sh adblock_update.sh adblock_reset.sh adblock_test.sh adblock_log.sh adblock_stats.sh adblock_export.sh adblock_import.sh; do
    cp "$BIN/actions/$a" "/tmp/$a"
    chmod 755 "/tmp/$a"
done

# First-boot NVRAM defaults for the settings page.
[ -z "$(nvram get adblock_enable)" ] && nvram set adblock_enable=1
[ -z "$(nvram get adblock_interval)" ] && nvram set adblock_interval=weekly
[ -z "$(nvram get adblock_presets)" ] && nvram set adblock_presets=127
[ -z "$(nvram get adblock_extra_sources)" ] && nvram set adblock_extra_sources=""
[ -z "$(nvram get adblock_sources)" ] && nvram set adblock_sources="$(cat "$DIR/sources.conf")"
[ -z "$(nvram get adblock_custom)" ] && nvram set adblock_custom="$(cat "$DIR/custom.hosts")"
[ -z "$(nvram get adblock_allow)" ] && nvram set adblock_allow="$(cat "$DIR/custom.allow")"
nvram commit

if [ "$(nvram get adblock_enable)" = "0" ]; then
    exit 0
fi

modprobe br_netfilter 2>/dev/null
sysctl -w net.bridge.bridge-nf-call-iptables=1 >/dev/null 2>&1
sysctl -w net.bridge.bridge-nf-call-ip6tables=1 >/dev/null 2>&1

if [ -f "$WORK/update.lock" ] && kill -0 "$(cat "$WORK/update.lock")" 2>/dev/null; then
    exit 0
fi
START_LOCK=$WORK/start.lock
if [ -f "$START_LOCK" ] && kill -0 "$(cat "$START_LOCK")" 2>/dev/null; then
    exit 0
fi
echo $$ > "$START_LOCK"
trap 'rm -f "$START_LOCK"' EXIT

rm -f "$WORK/hosts"

if [ ! -s "$WORK/hosts.v4" ] && [ -s "$DIR/hosts.gz" ]; then
    if gzip -dc "$DIR/hosts.gz" > "$WORK/hosts.v4.tmp" 2>/dev/null && [ -s "$WORK/hosts.v4.tmp" ]; then
        mv "$WORK/hosts.v4.tmp" "$WORK/hosts.v4"
    else
        rm -f "$WORK/hosts.v4.tmp"
    fi
fi

if [ ! -s "$WORK/hosts.v4" ]; then
    "$BIN/update.sh" >/dev/null 2>&1
fi

if [ -s "$WORK/hosts.v4" ] && [ ! -s "$WORK/hosts.v6" ]; then
    if awk '{print "::1 " $2}' "$WORK/hosts.v4" > "$WORK/hosts.v6.tmp" 2>/dev/null && [ -s "$WORK/hosts.v6.tmp" ]; then
        mv "$WORK/hosts.v6.tmp" "$WORK/hosts.v6"
    else
        rm -f "$WORK/hosts.v6.tmp"
    fi
fi

[ -s "$WORK/hosts.v4" ] || : > "$WORK/hosts.v4"
[ -s "$WORK/hosts.v6" ] || : > "$WORK/hosts.v6"
chmod 644 "$WORK/hosts.v4" "$WORK/hosts.v6"

write_cron() {
    mkdir -p /etc/storage/cron/crontabs
    TMP=/tmp/adblock-cron
    [ -f /etc/storage/cron/crontabs/admin ] && grep -v -E 'adblock|watchdog\.sh' /etc/storage/cron/crontabs/admin > "$TMP"
    {
        cat "$TMP" 2>/dev/null
        echo "* * * * * $BIN/watchdog.sh"
        case "$(nvram get adblock_interval)" in
            weekly) echo "15 4 * * 0 $BIN/update.sh";;
            off) ;;
            *) echo "15 4 * * * $BIN/update.sh";;
        esac
    } > /etc/storage/cron/crontabs/admin
    rm -f "$TMP"
    chmod 600 /etc/storage/cron/crontabs/admin
    pidof crond >/dev/null 2>&1 || crond -c /etc/storage/cron/crontabs
}

finish() {
    write_cron
    /sbin/mtd_storage.sh save >/dev/null 2>&1
    logger -t adblock "started ($1) with $(grep -c '^0\.0\.0\.0 ' "$WORK/hosts.v4") domains"
}

SW_MODE=$(nvram get sw_mode)
if [ "$SW_MODE" = "3" ]; then
    # AP mode: separate resolver + DNS redirects.
    if ! "$BIN/restart.sh"; then
        iptables -t nat -D PREROUTING -i br0 -p udp --dport 53 -j REDIRECT --to-ports 53 2>/dev/null
        iptables -t nat -D PREROUTING -i br0 -p tcp --dport 53 -j REDIRECT --to-ports 53 2>/dev/null
        ip6tables -D FORWARD -i br0 -p udp --dport 53 -j DROP 2>/dev/null
        ip6tables -D FORWARD -i br0 -p tcp --dport 53 -j DROP 2>/dev/null
        exit 1
    fi

    iptables -t nat -C PREROUTING -i br0 -p udp --dport 53 -j REDIRECT --to-ports 53 2>/dev/null || \
        iptables -t nat -I PREROUTING 1 -i br0 -p udp --dport 53 -j REDIRECT --to-ports 53
    iptables -t nat -C PREROUTING -i br0 -p tcp --dport 53 -j REDIRECT --to-ports 53 2>/dev/null || \
        iptables -t nat -I PREROUTING 1 -i br0 -p tcp --dport 53 -j REDIRECT --to-ports 53

    # The AP has no IPv6 address, so block IPv6 DNS and force IPv4 DNS fallback.
    ip6tables -C FORWARD -i br0 -p udp --dport 53 -j DROP 2>/dev/null || \
        ip6tables -I FORWARD 1 -i br0 -p udp --dport 53 -j DROP
    ip6tables -C FORWARD -i br0 -p tcp --dport 53 -j DROP 2>/dev/null || \
        ip6tables -I FORWARD 1 -i br0 -p tcp --dport 53 -j DROP

    finish "AP mode"
else
    # Router mode: use the firmware's own dnsmasq.
    DNSMASQ_CONF=/etc/storage/dnsmasq/dnsmasq.conf
    [ -f "$DNSMASQ_CONF" ] || : > "$DNSMASQ_CONF"
    grep -q 'adblock/dnsmasq.d' "$DNSMASQ_CONF" 2>/dev/null || \
        echo "conf-dir=/etc/storage/adblock/dnsmasq.d" >> "$DNSMASQ_CONF"

    mkdir -p "$DIR/dnsmasq.d"
    {
        echo "addn-hosts=$WORK/hosts.v4"
        echo "addn-hosts=$WORK/hosts.v6"
        echo "conf-file=$DIR/wildcard.conf"
        echo "log-queries"
        echo "log-facility=/tmp/adblock-queries.log"
    } > "$DIR/dnsmasq.d/adblock.conf"

    if [ -x /tmp/restart_dhcpd ]; then
        /tmp/restart_dhcpd
    else
        killall dnsmasq 2>/dev/null
        sleep 1
        /usr/sbin/dnsmasq
    fi

    finish "router mode"
fi
