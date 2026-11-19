# Adblock for Padavan-ng (RM-AC2100)

This fork adds a DNS blocklist service and a settings page to Padavan-ng.

## Features

- 7 default blocklist sources (AnudeepND, AdAway, StevenBlack, Pete Lowe,
  EasyList, EasyPrivacy, EasyList Hebrew)
- IPv4 **and** IPv6 blocking (`0.0.0.0` and `::1`)
- Gzipped NAND backup in `/etc/storage/adblock/hosts.gz`
- Weekly updates by default (daily optional), plus an "Update now" button
- Watchdog every minute
- Settings page: **Advanced → Customization → Adblock**
- Preset source checkboxes: 7 defaults + 12 regional lists
- Per-source download status
- Custom blocked domains textarea
- Allowlist textarea (domains and subdomains that are never blocked)
- Wildcard blocks for major ad networks (`address=/domain/0.0.0.0` + `::1`)
- AP mode and router mode
- Update rejection for critical domains, with previous-list rollback
- Diagnostics: test domain, update log, blocked-query stats, export/import settings, restore defaults
- Status line with the last domain count/update time
- Quick rebuild script and GitHub Actions build workflow

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

For quick user-space iterations (scripts, settings page, adblock package):

```sh
cd trunk
./quick-rebuild.sh
```

That reuses the toolchain, kernel and package build trees. The full
`build-adblock.sh` is only needed after config/kernel changes.

GitHub Actions workflow `.github/workflows/build.yml` builds the toolchain
(cached) and uploads the `.trx` plus `SHA256SUMS`.

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
| `CIFS`, `NFS`/`NFSD` | Network shares; no storage/AiDisk on this board |
| `EXT2/3/4`, `XFS`, `FAT/VFAT`, `EXFAT` | USB/storage filesystems; no USB |
| `USB video` | No USB support on this board |
| `LANG_RU` | English-only UI |
| `CURL` | adblock uses BusyBox wget; saves ~1.2 MB |
| `TOR`, `obfs4proxy` | Already disabled in the base template |

The Services submenu is shortened automatically when these are disabled.

Further candidates (kept by default to avoid breaking their UI pages):

- OpenVPN / StrongSwan / AmneziaWG (~3 MB)
- OpenSSH/SFTP (~1 MB; Dropbear is still included)
- XUPnPd (~1 MB)

Tor/obfs4proxy and curl/libcurl are disabled; the old `.trx`'s Tor
(~10 MB) and curl will not be in the new image.

The USB/storage/CIFS kernel modules and the Russian dictionary are now
removed; `STORAGE_ENABLED=n` already excludes Samba/NFS/AiDisk user-space
packages.

## Runtime layout

| Path | Purpose |
|---|---|
| `/usr/sbin/adblock/` | scripts and defaults (firmware) |
| `/etc/storage/adblock/sources.conf` | generated source URLs |
| `/etc/storage/adblock/custom.hosts` | manual blocked domains |
| `/etc/storage/adblock/custom.allow` | allowlist (never block) |
| `/etc/storage/adblock/wildcard.conf` | wildcard ad-network blocks |
| `/etc/storage/adblock/dnsmasq.conf` | AP-mode resolver config |
| `/etc/storage/adblock/dnsmasq.d/adblock.conf` | router-mode include |
| `/etc/storage/adblock/hosts.gz` | IPv4 list backup (NAND) |
| `/usr/sbin/adblock/defaults/presets.conf` | preset source catalog |
| `/tmp/adblock-queries.log` | dnsmasq query log for stats |
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

## NAND wear

Updates default to **weekly** to reduce NAND writes. Daily and off are available
on the settings page. `mtd_storage.sh save` only writes when the stored content
actually changes.

## Settings page

After flashing, open:

**Advanced → Customization → Adblock**

The page supports enable/disable, weekly/daily/off updates, preset source
checkboxes, extra source URLs, custom blocked domains, allowed domains,
per-source status, test-domain, update log, blocked-query stats,
export/import settings, restore defaults, and "Update now".

## Recovery

Keep the original RM-AC2100 image available for recovery. The build output is a
uImage with a squashfs rootfs; flash it through the Padavan web UI or Breed.
