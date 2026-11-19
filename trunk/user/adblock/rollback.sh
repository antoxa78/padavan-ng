#!/bin/sh
DIR=/etc/storage/adblock
PID=/var/run/adblock-dnsmasq.pid

if [ "$(nvram get sw_mode)" = "3" ]; then
    iptables -t nat -D PREROUTING -i br0 -p udp --dport 53 -j REDIRECT --to-ports 53 2>/dev/null
    iptables -t nat -D PREROUTING -i br0 -p tcp --dport 53 -j REDIRECT --to-ports 53 2>/dev/null
    ip6tables -D FORWARD -i br0 -p udp --dport 53 -j DROP 2>/dev/null
    ip6tables -D FORWARD -i br0 -p tcp --dport 53 -j DROP 2>/dev/null
    [ -s "$PID" ] && kill "$(cat "$PID")" 2>/dev/null
    rm -f "$PID"
else
    rm -f "$DIR/dnsmasq.d/adblock.conf"
    sed -i '\|conf-dir=/etc/storage/adblock/dnsmasq.d|d' /etc/storage/dnsmasq/dnsmasq.conf 2>/dev/null
    if [ -x /tmp/restart_dhcpd ]; then
        /tmp/restart_dhcpd
    else
        killall dnsmasq 2>/dev/null
        sleep 1
        /usr/sbin/dnsmasq
    fi
fi

sed -i '/adblock\/start.sh/d' /etc/storage/started_script.sh
sed -i '/adblock\/watchdog.sh/d' /etc/storage/cron/crontabs/admin 2>/dev/null
sed -i '/adblock\/update.sh/d' /etc/storage/cron/crontabs/admin 2>/dev/null
rm -rf /tmp/adblock "$DIR"
/sbin/mtd_storage.sh save >/dev/null 2>&1
logger -t adblock "stopped and removed"
