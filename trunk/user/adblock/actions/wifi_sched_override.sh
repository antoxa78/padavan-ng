#!/bin/sh
# Temporarily keep Wi-Fi radios (and guests) on, bypassing the weekly schedule.
MIN=$(nvram get wifi_sched_override_minutes)
case "$MIN" in ''|*[!0-9]*) MIN=60;; esac
[ "$MIN" -gt 1440 ] && MIN=1440

if [ "$MIN" -eq 0 ]; then
    UNTIL=0
else
    UNTIL=$(( $(date +%s) + MIN * 60 ))
fi

nvram set wifi_sched_override_until="$UNTIL"
nvram commit

# Ask rc to re-evaluate the radios immediately instead of waiting for the
# next watchdog pass.
mkdir -p /tmp/rc_notification /tmp/rc_action_incomplete
for e in control_wifi_radio_rt control_wifi_radio_wl control_wifi_guest_rt control_wifi_guest_wl; do
    : > "/tmp/rc_notification/$e"
    : > "/tmp/rc_action_incomplete/$e"
done
kill -USR1 1 2>/dev/null

if [ "$UNTIL" -eq 0 ]; then
    logger -t wifi-schedule "temporary override cleared"
else
    logger -t wifi-schedule "temporary override for $MIN minutes"
fi
