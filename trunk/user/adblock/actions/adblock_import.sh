#!/bin/sh
I=$(nvram get adblock_import)
if [ -z "$I" ]; then
    nvram set adblock_status="import: empty"
    nvram commit
    exit 0
fi
printf '%s\n' "$I" > /tmp/adblock-import.txt

for sec in presets extra custom allow interval update_hour update_min enable; do
    case "$sec" in
        presets)     var=adblock_presets ;;
        extra)       var=adblock_extra_sources ;;
        custom)      var=adblock_custom ;;
        allow)       var=adblock_allow ;;
        interval)    var=adblock_interval ;;
        update_hour) var=adblock_update_hour ;;
        update_min)  var=adblock_update_min ;;
        enable)      var=adblock_enable ;;
    esac
    VAL=$(awk -v s="[$sec]" '$0==s{f=1;next} /^\[/{f=0} f' /tmp/adblock-import.txt)
    nvram set "$var"="$VAL"
done
nvram set adblock_import=""
rm -f /tmp/adblock-import.txt
nvram commit
/usr/sbin/adblock/save.sh
