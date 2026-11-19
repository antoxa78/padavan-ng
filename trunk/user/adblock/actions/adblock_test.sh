#!/bin/sh
D=$(nvram get adblock_test_domain)
case "$D" in
    ''|*[!a-zA-Z0-9.-]*) R="Invalid domain" ;;
    *) R=$(nslookup "$D" 127.0.0.1 2>&1) ;;
esac
nvram set adblock_test_result="$R"
nvram commit
