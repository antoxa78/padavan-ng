#!/bin/sh
# Manual refresh: flush the current log and force the daily table to storage.
/usr/sbin/adblock/stats_collect.sh --sync
