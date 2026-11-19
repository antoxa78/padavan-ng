#!/bin/sh
nvram set adblock_status="updating..."
nvram commit
/usr/sbin/adblock/update.sh >/tmp/adblock-update.log 2>&1 &
