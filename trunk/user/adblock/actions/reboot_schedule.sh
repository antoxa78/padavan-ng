#!/bin/sh
# Maintain a single scheduled-reboot entry in the admin crontab.
ENABLE=$(nvram get reboot_sched_enable)
case "$ENABLE" in 0|1) ;; *) ENABLE=0;; esac

TIME=$(nvram get reboot_sched_time)
case "$TIME" in
    [0-9]:[0-9][0-9]|[0-9][0-9]:[0-9][0-9]) ;;
    *) TIME="04:30";;
esac
H=${TIME%%:*}
M=${TIME#*:}
H=$(echo "$H" | sed 's/^0*//'); [ -z "$H" ] && H=0
M=$(echo "$M" | sed 's/^0*//'); [ -z "$M" ] && M=0
[ "$H" -le 23 ] || H=4
[ "$M" -le 59 ] || M=30

DAYS=$(nvram get reboot_sched_days)
case "$DAYS" in ''|*[!0-9]*) DAYS=127;; esac
[ "$DAYS" -gt 127 ] && DAYS=127

DOW=""
if [ "$DAYS" -eq 127 ]; then
    DOW="*"
elif [ "$DAYS" -gt 0 ]; then
    i=0
    while [ "$i" -le 6 ]; do
        if [ $((DAYS & (1 << i))) -ne 0 ]; then
            DOW="${DOW:+$DOW,}$i"
        fi
        i=$((i + 1))
    done
fi

CRON=/etc/storage/cron/crontabs/admin
mkdir -p /etc/storage/cron/crontabs
TMP=/tmp/reboot-cron
if [ -f "$CRON" ]; then
    grep -v -E 'reboot-scheduler|/sbin/reboot' "$CRON" > "$TMP"
else
    : > "$TMP"
fi

if [ "$ENABLE" = "1" ] && [ -n "$DOW" ]; then
    echo "# reboot-scheduler" >> "$TMP"
    echo "$M $H * * $DOW /sbin/reboot" >> "$TMP"
fi

mv "$TMP" "$CRON"
chmod 600 "$CRON"

nvram set reboot_sched_enable="$ENABLE"
nvram set reboot_sched_time="$H:$M"
nvram set reboot_sched_days="$DAYS"
nvram commit

pidof crond >/dev/null 2>&1 || crond -c /etc/storage/cron/crontabs
/sbin/mtd_storage.sh save >/dev/null 2>&1
logger -t reboot-scheduler "enabled=$ENABLE time=$H:$M days=$DAYS"
