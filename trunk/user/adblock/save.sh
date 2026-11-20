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
# Strip angle brackets so a stored URL cannot break the page's textarea.
EXTRA=$(printf '%s\n' "$EXTRA" | tr -d '<>')
nvram set adblock_extra_sources="$EXTRA"
if [ -n "$EXTRA" ]; then
    printf '%s\n' "$EXTRA" | while IFS= read -r url; do
        case "$url" in
            ''|'#'*) continue;;
            *' '*|*'	'*|*'<'*|*'>'*|*'"'*|*"'"*)
                logger -t adblock "ignored unsafe source URL: $url";;
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
# Drop HTML metacharacters and blank lines so repeated saves are byte-stable.
CUSTOM=$(printf '%s\n' "$CUSTOM" | tr -d '<>\r' | sed '/^[[:space:]]*$/d')
nvram set adblock_custom="$CUSTOM"
printf '%s\n' "$CUSTOM" > "$DIR/custom.hosts.new"
mv "$DIR/custom.hosts.new" "$DIR/custom.hosts"

ALLOW=$(nvram get adblock_allow)
if [ -z "$ALLOW" ]; then
    ALLOW='# no allowlist'
fi
ALLOW=$(printf '%s\n' "$ALLOW" | tr -d '<>\r' | sed '/^[[:space:]]*$/d')
nvram set adblock_allow="$ALLOW"
printf '%s\n' "$ALLOW" > "$DIR/custom.allow.new"
mv "$DIR/custom.allow.new" "$DIR/custom.allow"

# Wildcard domains are stored one per line in NVRAM and expanded into dnsmasq
# address= rules.  Strip pasted URLs and wildcard prefixes so saves stay stable.
WILD=$(nvram get adblock_wildcard)
WILD=$(printf '%s\n' "$WILD" | tr -d '<>\r' | tr 'A-Z' 'a-z' |
    sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s|^https\?://||; s|/.*$||; s/^\*\.//; s/^\.//' |
    grep -E '^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$' |
    awk 'NF && !seen[$0]++')
nvram set adblock_wildcard="$WILD"
{
    echo "# Wildcard blocks: each entry matches the domain and all subdomains."
    echo "# Generated from the Adblock settings page."
    printf '%s\n' "$WILD" | while IFS= read -r d; do
        [ -n "$d" ] && printf 'address=/%s/0.0.0.0\naddress=/%s/::1\n' "$d" "$d"
    done
} > "$DIR/wildcard.conf.new"
mv "$DIR/wildcard.conf.new" "$DIR/wildcard.conf"

DOH_BLOCK=$(nvram get adblock_doh_block)
case "$DOH_BLOCK" in 0|1) ;; *) DOH_BLOCK=1;; esac
nvram set adblock_doh_block="$DOH_BLOCK"
REBIND=$(nvram get adblock_rebind)
case "$REBIND" in 0|1) ;; *) REBIND=0;; esac
nvram set adblock_rebind="$REBIND"

{
    echo "# Generated resolver options."
    [ "$REBIND" = "1" ] && echo "stop-dns-rebind"
    echo "conf-file=$DIR/doh.conf"
} > "$DIR/options.conf.new"
mv "$DIR/options.conf.new" "$DIR/options.conf"

if [ "$DOH_BLOCK" = "1" ]; then
    {
        echo "# Block DNS-over-HTTPS endpoints so clients use this resolver."
        echo "address=/use-application-dns.net/"
        for d in mozilla.cloudflare-dns.com firefox.dns.nextdns.io \
                 doh.opendns.com dns.google chrome.cloudflare-dns.com doh.dns.apple.com \
                 dns.nextdns.io doh.pub dns.alidns.com doh.360.cn cloudflare-dns.com \
                 dns.quad9.net doh.cleanbrowsing.org doh.adguard.com dns.adguard.com; do
            printf 'address=/%s/0.0.0.0\naddress=/%s/::1\n' "$d" "$d"
        done
    } > "$DIR/doh.conf.new"
else
    echo "# DoH blocking disabled" > "$DIR/doh.conf.new"
fi
mv "$DIR/doh.conf.new" "$DIR/doh.conf"

# Compare the saved configuration with the configuration used to build the
# active list.  This stays correct even if the user changes settings and then
# changes them back before pressing "Update list".
CONFIG_HASH=$( { cat "$DIR/sources.conf"; echo '---'; cat "$DIR/custom.hosts"; echo '---'; cat "$DIR/custom.allow"; echo '---'; cat "$DIR/wildcard.conf"; echo '---'; cat "$DIR/options.conf"; echo '---'; cat "$DIR/doh.conf"; } | md5sum | cut -d' ' -f1)
APPLIED_HASH=$(nvram get adblock_applied_hash)
if [ "$CONFIG_HASH" = "$APPLIED_HASH" ]; then
    DIRTY=0
else
    DIRTY=1
fi

nvram set adblock_sources="$(cat "$DIR/sources.conf")"
nvram set adblock_config_hash="$CONFIG_HASH"

PAUSE_UNTIL=$(nvram get adblock_pause_until)
case "$PAUSE_UNTIL" in ''|*[!0-9]*) PAUSE_UNTIL=0;; esac
PAUSED=0
[ "$PAUSE_UNTIL" -gt "$(date +%s)" ] 2>/dev/null && PAUSED=1

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
        if [ "$PAUSED" = "1" ]; then
            nvram set adblock_phase=paused
            nvram set adblock_config_dirty="$DIRTY"
            nvram set adblock_status="paused (settings saved)"
        elif [ "$DIRTY" = "1" ]; then
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
