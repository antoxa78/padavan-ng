#!/bin/sh
emit() {
    printf '[%s]\n' "$1"
    printf '%s\n' "$(nvram get "$2")"
}

{
    emit presets adblock_presets
    emit extra adblock_extra_sources
    emit custom adblock_custom
    emit allow adblock_allow
    emit wildcard adblock_wildcard
    emit doh_block adblock_doh_block
    emit rebind adblock_rebind
    emit interval adblock_interval
    emit update_hour adblock_update_hour
    emit update_min adblock_update_min
    emit enable adblock_enable
} > /tmp/adblock-export.txt
nvram set adblock_export="$(cat /tmp/adblock-export.txt)"
nvram commit
