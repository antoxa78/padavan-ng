#!/bin/sh
# Check the adblock ASP pages for directives this httpd cannot process.
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
DIR="$ROOT/user/www/n56u_ribbon_fixed"
FAIL=0

for f in "$DIR/Advanced_Adblock_Content.asp" "$DIR/Advanced_Adblock_Diagnostics.asp"; do
    [ -f "$f" ] || { echo "missing: $f"; FAIL=1; continue; }

    if grep -nE '\bnvram_(get|match)[[:space:]]*\(' "$f"; then
        echo "ERROR: $f uses nvram_get/nvram_match; use nvram_get_x/nvram_match_x"
        FAIL=1
    fi

    if grep -n 'nvram_dump' "$f"; then
        echo "ERROR: $f uses nvram_dump"
        FAIL=1
    fi
done

if [ "$FAIL" -eq 0 ]; then
    echo "adblock ASP lint: OK"
fi
exit "$FAIL"
