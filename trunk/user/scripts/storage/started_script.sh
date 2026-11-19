#!/bin/sh

### Custom user script
### Called after router started and network is ready

### Adblock
[ -x /usr/sbin/adblock/start.sh ] && /usr/sbin/adblock/start.sh
