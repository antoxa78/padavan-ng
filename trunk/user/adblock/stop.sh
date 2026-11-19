#!/bin/sh
iptables -t nat -D PREROUTING -i br0 -p udp --dport 53 -j REDIRECT --to-ports 53 2>/dev/null
iptables -t nat -D PREROUTING -i br0 -p tcp --dport 53 -j REDIRECT --to-ports 53 2>/dev/null
ip6tables -D FORWARD -i br0 -p udp --dport 53 -j DROP 2>/dev/null
ip6tables -D FORWARD -i br0 -p tcp --dport 53 -j DROP 2>/dev/null

PID=/var/run/adblock-dnsmasq.pid
[ -s "$PID" ] && kill "$(cat "$PID")" 2>/dev/null
rm -f "$PID"
logger -t adblock "stopped"
