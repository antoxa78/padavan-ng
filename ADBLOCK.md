# Adblock for Padavan-ng (RM-AC2100)

This fork adds a DNS blocklist service and a settings page to Padavan-ng.

## Features

- 7 default blocklist sources (AnudeepND, AdAway, StevenBlack, Pete Lowe,
  EasyList, EasyPrivacy, EasyList Hebrew)
- IPv4 **and** IPv6 blocking (`0.0.0.0` and `::1`)
- Gzipped NAND backup in `/etc/storage/adblock/hosts.gz`
- Daily or weekly updates, plus a "Update now" button
- Watchdog every minute
- Settings page: **Advanced → Customization → Adblock**
- Custom blocked domains textarea
- Allowlist textarea (domains and subdomains that are never blocked)
- Wildcard blocks for major ad networks (`address=/domain/0.0.0.0` + `::1`)
- AP mode and router mode
- Update rejection for critical domains, with previous-list rollback
- Status line with the last domain count/update time

## Build

Install the dependencies listed in the main README (Ubuntu 24.04):

```sh
sudo apt install --no-install-recommends -y \
  autoconf automake autopoint cmake bison build-essential flex gawk gettext \
  git gperf libtool libtool-bin pkg-config fakeroot kmod cpio doxygen texinfo \
  help2man libncurses-dev zlib1g-dev libsqlite3-dev gcc-multilib curl dos2unix \
  unzip wget locales xxd libltdl-dev libgmp3-dev libmpfr-dev libarchive-tools \
  libblkid-dev ca-certificates zstd mc bc
```

Then:

```sh
cd padavan-ng/trunk
cp configs/templates/XIAOMI/rm-ac2100-adblock.config .config
./build_firmware.sh
```

The image is written to `trunk/images/`.

Use `rm-ac2100.config` instead of `rm-ac2100-adblock.config` if you want the
full feature set.

## Lean config

`rm-ac2100-adblock.config` disables these optional packages:

| Option | Reason |
|---|---|
| `ADB` | No USB ADB on this board |
| `DNSCRYPT` | dnsmasq is the resolver |
| `DOH` | dnsmasq is the resolver |
| `STUBBY` | dnsmasq is the resolver |
| `ZAPRET`, `ZAPRET2` | DPI bypass, unrelated to adblock |
| `IPSET` | adblock uses dnsmasq hosts, not ipsets |
| `TCPDUMP` | diagnostics only |
| `WPAD` | proxy auto-discovery not needed |

The Services submenu is shortened automatically when these are disabled.

Further candidates (kept by default to avoid breaking their UI pages):

- OpenVPN / StrongSwan / AmneziaWG (~3 MB)
- Tor / obfs4proxy (~10 MB, already disabled in the base template)
- curl/libcurl (~1.2 MB)
- OpenSSH/SFTP (~1 MB; Dropbear is still included)
- XUPnPd (~1 MB)
- USB/storage/CIFS kernel modules (~1.5 MB; the board has no USB)

## Runtime layout

| Path | Purpose |
|---|---|
| `/usr/sbin/adblock/` | scripts and defaults (firmware) |
| `/etc/storage/adblock/sources.conf` | source URLs |
| `/etc/storage/adblock/custom.hosts` | manual blocked domains |
| `/etc/storage/adblock/custom.allow` | allowlist (never block) |
| `/etc/storage/adblock/wildcard.conf` | wildcard ad-network blocks |
| `/etc/storage/adblock/dnsmasq.conf` | AP-mode resolver config |
| `/etc/storage/adblock/dnsmasq.d/adblock.conf` | router-mode include |
| `/etc/storage/adblock/hosts.gz` | IPv4 list backup (NAND) |
| `/tmp/adblock/hosts.v4` | live IPv4 list |
| `/tmp/adblock/hosts.v6` | live IPv6 list |
| `/tmp/adblock_apply.sh` | UI apply action |
| `/tmp/adblock_update.sh` | UI update action |

## Modes

- **AP mode** (`sw_mode=3`): starts a separate dnsmasq, redirects IPv4 DNS,
  and drops IPv6 DNS so clients fall back to the filtered resolver.
- **Router mode**: integrates with the firmware's own dnsmasq through
  `conf-dir=/etc/storage/adblock/dnsmasq.d` in
  `/etc/storage/dnsmasq/dnsmasq.conf`.

## Settings page

After flashing, open:

**Advanced → Customization → Adblock**

The page supports enable/disable, daily/weekly/off updates, source URLs,
custom blocked domains, allowed domains, status, and "Update now".

## Recovery

Keep the original RM-AC2100 image available for recovery. The build output is a
uImage with a squashfs rootfs; flash it through the Padavan web UI or Breed.
