# SQM / QoS for Padavan-ng (RM-AC2100)

This fork adds a small Smart Queue Management (SQM) and simple QoS page.

## What it does

- **SQM / bufferbloat control** on the WAN interface using `HTB` + `fq_codel`.
  Traffic is shaped to a configurable percentage (default 95%) of the measured
  upload/download speed, so queues stay short and latency stays low while the
  line is busy.
- **Upload shaping** is enabled by setting the upload speed.
- **Download shaping** is optional. It redirects WAN ingress through `ifb0`
  and shapes it with a second `HTB` tree. It uses more CPU than upload shaping.
- **Per-client upload limits** by IPv4 address, in Mbit/s. Upload packets are
  marked with iptables and matched by the `fw` classifier on the WAN queue.
  Download traffic is shared and kept fair by `fq_codel`; per-client download
  caps are not available in this version.

The page is at **Advanced → Customization → SQM / QoS**.

## It does not improve audio bitrate

SQM cannot raise the quality of a music service. It only keeps the connection
responsive and prevents stutter/dropouts when other traffic saturates the line.
Choose the highest quality in the music app itself (for example “Very High”,
“Lossless” or “Hi-Res”). Lossless audio needs only a few Mbit/s; the real
requirements are stable Wi-Fi and enough spare bandwidth.

## Configuration

1. Run a speed test with the router otherwise idle.
2. Enter the measured **upload** and **download** speeds in Mbit/s.
3. Keep **Shaping percentage** at 90–95%.
4. Leave **Download shaping** enabled for the best latency, or disable it to
   reduce CPU load.
5. Press **Save & apply**.

Per-client upload limits are optional. They need the WAN upload speed to be
set. Use Static DHCP (Advanced → LAN → DHCP Server) so a device keeps the same
IPv4 address.

## Hardware offload

The MT7621 hardware NAT/offload (`hw_nat`) can bypass Linux `tc` queues. If SQM
seems to have no effect, set **Advanced → WAN → Hardware NAT** to
**Disable (Slow)**. This lowers maximum routing throughput but makes shaping
effective. The SQM page shows the current offload state.

## Runtime layout

| Path | Purpose |
|---|---|
| `/usr/sbin/sqm/start.sh` | Boot entry: defaults, UI action, apply/stop |
| `/usr/sbin/sqm/apply.sh` | Build the HTB/fq_codel trees |
| `/usr/sbin/sqm/stop.sh` | Remove all SQM queues |
| `/usr/sbin/sqm/wan_hook.sh` | Re-apply when WAN goes up/down |
| `/usr/sbin/sqm/common.sh` | Shared helpers |
| `/tmp/sqm_save.sh` | Web UI apply action |
| `/tmp/sqm_stop.sh` | Web UI stop action |
| `/tmp/sqm.lock` | Apply serialization lock |

## NVRAM variables

| Variable | Meaning |
|---|---|
| `sqm_enable` | `0` disabled, `1` enabled |
| `sqm_upload_mbps` | Measured WAN upload speed in Mbit/s |
| `sqm_download_mbps` | Measured WAN download speed in Mbit/s |
| `sqm_download_shape` | `1` enable IFB download shaping, `0` upload only |
| `sqm_overhead` | Shaping percentage, 50–100 |
| `sqm_clients` | Per-client rows, one per line: `IP|upload_mbps` |
| `sqm_status` | Last state (`active`, `disabled`, `error`, ...) |
| `sqm_summary` | Human-readable status line |
| `sqm_last_error` | Last apply error |
| `sqm_active_iface` | Interface the rules are attached to |
| `sqm_applied` | Last successful apply time |
| `sqm_link_speed` | WAN link speed from `/sys/class/net/<if>/speed` |
| `sqm_rule_count` | Number of installed queue/client rules |

## Limitations

- Per-client upload limits are IPv4-only. Per-client download caps are not
  implemented; download fairness comes from `fq_codel`.
- The kernel is 3.4, so CAKE is not available; `fq_codel` is used instead.
- Software shaping on the MT7621 is CPU-bound. A few hundred Mbit/s is a
  realistic ceiling; do not enter gigabit rates and expect gigabit shaping.
- Download shaping requires the IFB module. It is enabled in the RM-AC2100
  templates (`CONFIG_FIRMWARE_INCLUDE_QOS` and `CONFIG_FIRMWARE_INCLUDE_IFB`).
- Hardware NAT offload may bypass shaping; see above.
- SQM is not available in AP mode; the tab is hidden there because AP mode
  bridges traffic and has no routed WAN interface.

## Troubleshooting

Check the queues from SSH:

```sh
tc -s qdisc show dev eth2.2
tc -s qdisc show dev ifb0
tc class show dev eth2.2
tc filter show dev eth2.2
```

Check the log:

```sh
logread | grep sqm
```

If the state is `error`, the page shows the last error. Common causes are a
missing IFB module or an attempt to enable SQM before the WAN is up.
