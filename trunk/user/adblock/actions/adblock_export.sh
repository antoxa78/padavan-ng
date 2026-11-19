#!/bin/sh
{
    echo "[presets]"
    nvram get adblock_presets
    echo "[extra]"
    nvram get adblock_extra_sources
    echo "[custom]"
    nvram get adblock_custom
    echo "[allow]"
    nvram get adblock_allow
    echo "[interval]"
    nvram get adblock_interval
    echo "[enable]"
    nvram get adblock_enable
} > /tmp/adblock-export.txt
nvram set adblock_export="$(cat /tmp/adblock-export.txt)"
nvram commit
