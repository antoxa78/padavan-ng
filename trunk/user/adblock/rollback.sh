#!/bin/sh
BIN=$(cd "$(dirname "$0")" && pwd)
DIR=/etc/storage/adblock

iptables -t nat -D PREROUTING -i br0 -p udp --dport 53 -j REDIRECT --to-ports 53 2>/dev/null
iptables -t nat -D PREROUTING -i br0 -p tcp --dport 53 -j REDIRECT --to-ports 53 2>/dev/null
ip6tables -D FORWARD -i br0 -p udp --dport 53 -j DROP 2>/dev/null
ip6tables -D FORWARD -i br0 -p tcp --dport 53 -j DROP 2>/dev/null

PID=/var/run/adblock-dnsmasq.pid
[ -s "$PID" ] && kill "$(cat "$PID")" 2>/dev/null
rm -f "$PID"

sed -i '/adblock\/start.sh/d' /etc/storage/started_script.sh
sed -i '/adblock\/watchdog.sh/d' /etc/storage/cron/crontabs/admin 2>/dev/null
sed -i '/adblock\/update.sh/d' /etc/storage/cron/crontabs/admin 2>/dev/null
rm -rf /tmp/adblock /etc/storage/adblock
/sbin/mtd_storage.sh save >/dev/null 2>&1
logger -t adblock "stopped and removed"
