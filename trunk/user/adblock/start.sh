#!/bin/sh
BIN=$(cd "$(dirname "$0")" && pwd)
DIR=/etc/storage/adblock
WORK=/tmp/adblock
PID=/var/run/adblock-dnsmasq.pid

NO_UPDATE=0
[ "$1" = "--no-update" ] && NO_UPDATE=1
[ "$ADBLOCK_NO_UPDATE" = "1" ] && NO_UPDATE=1

mkdir -p "$DIR" "$DIR/stats" "$WORK"
[ -f "$DIR/stats/daily.tsv" ] || : > "$DIR/stats/daily.tsv"
[ -f "$DIR/sources.conf" ] || cp "$BIN/defaults/sources.conf" "$DIR/sources.conf"
[ -f "$DIR/custom.hosts" ] || cp "$BIN/defaults/custom.hosts" "$DIR/custom.hosts"
[ -f "$DIR/custom.allow" ] || cp "$BIN/defaults/custom.allow" "$DIR/custom.allow"
[ -f "$DIR/wildcard.conf" ] || cp "$BIN/defaults/wildcard.conf" "$DIR/wildcard.conf"
[ -f "$DIR/dnsmasq.conf" ] || cp "$BIN/defaults/dnsmasq.conf" "$DIR/dnsmasq.conf"
[ -f "$DIR/options.conf" ] || : > "$DIR/options.conf"
[ -f "$DIR/doh.conf" ] || : > "$DIR/doh.conf"

# dnsmasq 2.93 in this build ignores plain server= lines; migrate old configs
# to the resolv-file form and always generate the upstream file.
if [ -f "$DIR/dnsmasq.conf" ]; then
    sed -i '/^server=/d; /^no-resolv$/d' "$DIR/dnsmasq.conf"
    grep -q '^resolv-file=' "$DIR/dnsmasq.conf" || \
        echo "resolv-file=/etc/storage/adblock/resolv.conf" >> "$DIR/dnsmasq.conf"
    grep -q '^conf-file=.*/options\.conf' "$DIR/dnsmasq.conf" || \
        echo "conf-file=$DIR/options.conf" >> "$DIR/dnsmasq.conf"
fi

# AP mode: use the main router (default gateway) as the upstream resolver.
LANIP=$(ip -4 addr show br0 2>/dev/null | awk '/inet / {sub(/\/.*/,"",$2); print $2; exit}')
[ -z "$LANIP" ] && LANIP=$(nvram get lan_ipaddr)
GW=$(ip route 2>/dev/null | awk '/^default / {print $3; exit}')
[ -z "$GW" ] && GW=$(awk -v lan="$LANIP" '/^nameserver/ && $2 != lan && $2 !~ /^127\./ {print $2; exit}' /etc/resolv.conf 2>/dev/null)
[ -z "$GW" ] && GW=192.168.31.1
echo "nameserver $GW" > "$DIR/resolv.conf"

# Action scripts used by the web UI.  Copy to a temporary name and rename so a
# script that is currently executing is never truncated underneath itself.
for a in adblock_apply.sh adblock_save.sh adblock_update.sh adblock_reset.sh adblock_test.sh adblock_log.sh adblock_stats.sh adblock_export.sh adblock_import.sh adblock_pause.sh adblock_resume.sh adblock_allow.sh adblock_health.sh wifi_sched_override.sh reboot_schedule.sh; do
    if [ -f "$BIN/actions/$a" ]; then
        cp "$BIN/actions/$a" "/tmp/$a.new" && mv "/tmp/$a.new" "/tmp/$a"
        chmod 755 "/tmp/$a"
    fi
done

# First-boot NVRAM defaults for the settings page.
[ -z "$(nvram get adblock_enable)" ] && nvram set adblock_enable=1
[ -z "$(nvram get adblock_interval)" ] && nvram set adblock_interval=weekly
[ -z "$(nvram get adblock_update_hour)" ] && nvram set adblock_update_hour=4
[ -z "$(nvram get adblock_update_min)" ] && nvram set adblock_update_min=15
[ -z "$(nvram get adblock_presets)" ] && nvram set adblock_presets=127
[ -z "$(nvram get adblock_extra_sources)" ] && nvram set adblock_extra_sources=""
[ -z "$(nvram get adblock_sources)" ] && nvram set adblock_sources="$(cat "$DIR/sources.conf")"
[ -z "$(nvram get adblock_custom)" ] && nvram set adblock_custom="$(cat "$DIR/custom.hosts")"
[ -z "$(nvram get adblock_allow)" ] && nvram set adblock_allow="$(cat "$DIR/custom.allow")"
if [ -z "$(nvram get adblock_wildcard)" ]; then
    WILD=$(sed -n 's|^address=/\([^/]*\)/0\.0\.0\.0$|\1|p' "$DIR/wildcard.conf" 2>/dev/null | awk 'NF && !seen[$0]++')
    nvram set adblock_wildcard="$WILD"
fi
[ -z "$(nvram get adblock_pause_until)" ] && nvram set adblock_pause_until=0
[ -z "$(nvram get adblock_doh_block)" ] && nvram set adblock_doh_block=1
[ -z "$(nvram get adblock_rebind)" ] && nvram set adblock_rebind=0
[ -z "$(nvram get wifi_sched_override_until)" ] && nvram set wifi_sched_override_until=0
[ -z "$(nvram get reboot_sched_enable)" ] && nvram set reboot_sched_enable=0
[ -z "$(nvram get reboot_sched_time)" ] && nvram set reboot_sched_time="04:30"
[ -z "$(nvram get reboot_sched_days)" ] && nvram set reboot_sched_days=127
[ -z "$(nvram get adblock_phase)" ] && nvram set adblock_phase=idle
[ -z "$(nvram get adblock_progress)" ] && nvram set adblock_progress=""
[ -z "$(nvram get adblock_last_attempt)" ] && nvram set adblock_last_attempt="never"
[ -z "$(nvram get adblock_update_started)" ] && nvram set adblock_update_started=""
[ -z "$(nvram get adblock_config_dirty)" ] && nvram set adblock_config_dirty=0
[ -z "$(nvram get adblock_config_hash)" ] && nvram set adblock_config_hash=""
[ -z "$(nvram get adblock_applied_hash)" ] && nvram set adblock_applied_hash=""
[ -z "$(nvram get adblock_applied_options_hash)" ] && nvram set adblock_applied_options_hash=""
if [ -z "$(nvram get adblock_applied_options_hash)" ] && [ -n "$(nvram get adblock_applied_hash)" ]; then
    # Existing blocklist predates wildcard/DoH/rebind support: ask for one update.
    nvram set adblock_config_dirty=1
fi
[ -z "$(nvram get adblock_source_status)" ] && nvram set adblock_source_status=""
[ -z "$(nvram get adblock_stats_short)" ] && nvram set adblock_stats_short="Blocked today: 0 · this month: 0"
[ -z "$(nvram get adblock_stats)" ] && nvram set adblock_stats="Blocked queries
  today: 0
  this month: 0
  all time: 0"
PRESET_CFG=$(cat "$BIN/defaults/presets.conf")
[ "$(nvram get adblock_presets_config)" != "$PRESET_CFG" ] && nvram set adblock_presets_config="$PRESET_CFG"
nvram commit

# A pause survives reboots: keep the live lists empty until it expires.
PAUSE_UNTIL=$(nvram get adblock_pause_until)
case "$PAUSE_UNTIL" in ''|*[!0-9]*) PAUSE_UNTIL=0;; esac
PAUSED=0
[ "$PAUSE_UNTIL" -gt "$(date +%s)" ] 2>/dev/null && PAUSED=1

# Flush the in-memory daily statistics to storage on shutdown.
SHUTDOWN=/etc/storage/shutdown_script.sh
if [ -f "$SHUTDOWN" ] && ! grep -q 'adblock/stats_collect.sh --sync' "$SHUTDOWN" 2>/dev/null; then
    printf '%s\n' '[ -x /usr/sbin/adblock/stats_collect.sh ] && /usr/sbin/adblock/stats_collect.sh --sync >/dev/null 2>&1' >> "$SHUTDOWN"
fi

if [ "$(nvram get adblock_enable)" = "0" ]; then
    nvram set adblock_status="disabled"
    nvram set adblock_phase=disabled
    nvram set adblock_progress=""
    nvram commit
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

if [ "$PAUSED" = "1" ]; then
    # Paused: the resolver stays up, but both live lists are empty.
    : > "$WORK/hosts.v4"
    : > "$WORK/hosts.v6"
else
    rm -f "$WORK/hosts"

    if [ ! -s "$WORK/hosts.v4" ] && [ -s "$DIR/hosts.gz" ]; then
        if gzip -dc "$DIR/hosts.gz" > "$WORK/hosts.v4.tmp" 2>/dev/null && [ -s "$WORK/hosts.v4.tmp" ]; then
            mv "$WORK/hosts.v4.tmp" "$WORK/hosts.v4"
        else
            rm -f "$WORK/hosts.v4.tmp"
        fi
    fi

    if [ ! -s "$WORK/hosts.v4" ]; then
        if [ "$NO_UPDATE" = "1" ]; then
            nvram set adblock_config_dirty=1
            nvram set adblock_status="no blocklist yet; update list to apply"
            nvram set adblock_phase=idle
            nvram set adblock_progress=""
            nvram commit
        else
            "$BIN/update.sh" >/dev/null 2>&1
        fi
    fi

    if [ -s "$WORK/hosts.v4" ] && [ ! -s "$WORK/hosts.v6" ]; then
        if sed 's/^0\.0\.0\.0 /::1 /' "$WORK/hosts.v4" > "$WORK/hosts.v6.tmp" 2>/dev/null && [ -s "$WORK/hosts.v6.tmp" ]; then
            mv "$WORK/hosts.v6.tmp" "$WORK/hosts.v6"
        else
            rm -f "$WORK/hosts.v6.tmp"
        fi
    fi

    [ -s "$WORK/hosts.v4" ] || : > "$WORK/hosts.v4"
    [ -s "$WORK/hosts.v6" ] || : > "$WORK/hosts.v6"
fi
chmod 644 "$WORK/hosts.v4" "$WORK/hosts.v6"

write_cron() {
    mkdir -p /etc/storage/cron/crontabs
    TMP=/tmp/adblock-cron
    [ -f /etc/storage/cron/crontabs/admin ] && grep -v -E 'adblock|watchdog\.sh' /etc/storage/cron/crontabs/admin > "$TMP"

    HOUR=$(nvram get adblock_update_hour)
    MIN=$(nvram get adblock_update_min)
    [ -z "$HOUR" ] && HOUR=4
    [ -z "$MIN" ] && MIN=15
    HOUR=$(echo "$HOUR" | sed 's/^0*//')
    MIN=$(echo "$MIN" | sed 's/^0*//')
    [ -z "$HOUR" ] && HOUR=0
    [ -z "$MIN" ] && MIN=0
    case "$HOUR" in *[!0-9]*) HOUR=4;; esac
    case "$MIN" in *[!0-9]*) MIN=15;; esac
    [ "$HOUR" -le 23 ] || HOUR=4
    [ "$MIN" -le 59 ] || MIN=15
    H12=$(((HOUR + 12) % 24))
    H6B=$(((HOUR + 6) % 24))
    H6C=$(((HOUR + 12) % 24))
    H6D=$(((HOUR + 18) % 24))

    {
        cat "$TMP" 2>/dev/null
        echo "* * * * * $BIN/watchdog.sh"
        case "$(nvram get adblock_interval)" in
            weekly) echo "$MIN $HOUR * * 0 $BIN/update.sh";;
            12h)    echo "$MIN $HOUR,$H12 * * * $BIN/update.sh";;
            6h)     echo "$MIN $HOUR,$H6B,$H6C,$H6D * * * $BIN/update.sh";;
            off)    ;;
            *)      echo "$MIN $HOUR * * * $BIN/update.sh";;
        esac
    } > /etc/storage/cron/crontabs/admin
    rm -f "$TMP"
    chmod 600 /etc/storage/cron/crontabs/admin
    pidof crond >/dev/null 2>&1 || crond -c /etc/storage/cron/crontabs
}

finish() {
    LINES=$(grep -c '^0\.0\.0\.0 ' "$WORK/hosts.v4")
    write_cron
    /sbin/mtd_storage.sh save >/dev/null 2>&1
    if [ "${ADBLOCK_KEEP_STATUS:-0}" != "1" ]; then
        if [ "$PAUSED" = "1" ]; then
            nvram set adblock_status="paused (DNS filtering off)"
            nvram set adblock_phase=paused
            nvram set adblock_progress=""
        else
            nvram set adblock_status="$LINES domains (ready)"
            nvram set adblock_phase=idle
            nvram set adblock_progress=""
        fi
        [ -z "$(nvram get adblock_last_success)" ] && nvram set adblock_last_success="never"
        [ -z "$(nvram get adblock_last_attempt)" ] && nvram set adblock_last_attempt="never"
    fi
    nvram commit
    logger -t adblock "started ($1) with $LINES domains"
}

SW_MODE=$(nvram get sw_mode)
if [ "$SW_MODE" = "3" ]; then
    # AP mode: separate resolver + DNS redirects.
    # Do not bounce a healthy resolver just because settings were saved; the
    # active blocklist is only replaced by update.sh.
    NEED_RESTART=1
    if [ -s "$PID" ] && kill -0 "$(cat "$PID")" 2>/dev/null && \
            { [ -s "$WORK/hosts.v4" ] || [ "$PAUSED" = "1" ]; }; then
        NEED_RESTART=0
    fi
    if [ "$NEED_RESTART" = "1" ] && ! "$BIN/restart.sh"; then
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
        echo "conf-file=$DIR/options.conf"
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
