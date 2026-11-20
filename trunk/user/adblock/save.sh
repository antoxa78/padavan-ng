#!/bin/sh
# Persist Adblock settings without downloading any lists.
# The active blocklist is left untouched; adblock_config_dirty tells the UI
# that "Update list" is required to apply source/custom/allow changes.
BIN=$(cd "$(dirname "$0")" && pwd)
DIR=/etc/storage/adblock
PRESETS=$BIN/defaults/presets.conf

mkdir -p "$DIR"

MASK=$(nvram get adblock_presets)
case "$MASK" in ''|*[!0-9]*) MASK=127;; esac

TMP=$DIR/sources.conf.new
: > "$TMP"
while IFS='|' read -r idx label url; do
    case "$idx" in ''|'#'*) continue;; esac
    if [ $((MASK & (1 << idx))) -ne 0 ]; then
        echo "$url" >> "$TMP"
    fi
done < "$PRESETS"

EXTRA=$(nvram get adblock_extra_sources)
if [ -n "$EXTRA" ]; then
    printf '%s\n' "$EXTRA" | while IFS= read -r url; do
        case "$url" in
            ''|'#'*) continue;;
            http://*|https://*) echo "$url" >> "$TMP";;
            *) logger -t adblock "ignored invalid source URL: $url";;
        esac
    done
fi

# A non-zero mask with no matching presets means the preset table is broken;
# fall back to the shipped defaults instead of silently downloading nothing.
if [ ! -s "$TMP" ] && [ "$MASK" -ne 0 ]; then
    cp "$BIN/defaults/sources.conf" "$TMP"
    nvram set adblock_presets=127
fi

mv "$TMP" "$DIR/sources.conf"

CUSTOM=$(nvram get adblock_custom)
printf '%s\n' "$CUSTOM" > "$DIR/custom.hosts.new"
mv "$DIR/custom.hosts.new" "$DIR/custom.hosts"

ALLOW=$(nvram get adblock_allow)
if [ -z "$ALLOW" ]; then
    ALLOW='# no allowlist'
    nvram set adblock_allow="$ALLOW"
fi
printf '%s\n' "$ALLOW" > "$DIR/custom.allow.new"
mv "$DIR/custom.allow.new" "$DIR/custom.allow"

# Compare the saved configuration with the configuration used to build the
# active list.  This stays correct even if the user changes settings and then
# changes them back before pressing "Update list".
CONFIG_HASH=$( { cat "$DIR/sources.conf"; echo '---'; cat "$DIR/custom.hosts"; echo '---'; cat "$DIR/custom.allow"; } | md5sum | cut -d' ' -f1)
OLD_HASH=$(nvram get adblock_config_hash)
CHANGED_TS=$(nvram get adblock_config_changed)
if [ "$CONFIG_HASH" != "$OLD_HASH" ] || [ -z "$CHANGED_TS" ]; then
    nvram set adblock_config_changed="$(date '+%Y-%m-%d %H:%M')"
fi
APPLIED_HASH=$(nvram get adblock_applied_hash)
if [ "$CONFIG_HASH" = "$APPLIED_HASH" ]; then
    DIRTY=0
else
    DIRTY=1
fi

nvram set adblock_sources="$(cat "$DIR/sources.conf")"
nvram set adblock_config_hash="$CONFIG_HASH"

if [ "$(nvram get adblock_enable)" = "0" ]; then
    "$BIN/stop.sh" >/dev/null 2>&1
    nvram set adblock_phase=disabled
    nvram set adblock_progress=""
    nvram set adblock_status="disabled"
    nvram set adblock_config_dirty="$DIRTY"
else
    if ADBLOCK_NO_UPDATE=1 "$BIN/start.sh" >/dev/null 2>&1; then
        nvram set adblock_phase=idle
        nvram set adblock_progress=""
        if [ "$DIRTY" = "1" ]; then
            nvram set adblock_config_dirty=1
            nvram set adblock_status="settings saved; update list to apply"
        else
            nvram set adblock_config_dirty=0
            nvram set adblock_status="settings saved"
        fi
    else
        nvram set adblock_phase=error
        nvram set adblock_progress="DNS failed to start"
        nvram set adblock_status="settings saved; DNS failed to start"
        nvram set adblock_config_dirty="$DIRTY"
    fi
fi

nvram commit
logger -t adblock "settings saved (dirty=$DIRTY)"
