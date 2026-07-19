# W1700K HW2.1 Bouygues custom v2

This repository builds a pinned OpenWrt image for the Gemtek W1700K HW2.1
used on a Bouygues/B&You routed connection:

- target: `airoha/an7581`
- image profile: `gemtek_w1700k-ubi2`
- WAN PHY: Realtek RTL8261CE
- WAN: DHCP on VLAN 100
- IPv6: routed DHCPv6-PD `/60`, without NAT6

The v2 artifact is based on Gilly's 19.07 universal build. It is compiled from
source; the binary image from Gilly is not repackaged.

## Status

The first v2 release remains a prerelease labelled:

```text
[UNTESTED ON HW2.1 - DO NOT FLASH YET]
```

Building or publishing an image does not authorize an automatic router flash.
No workflow in this repository connects to the router.

The active router remains on the separately validated Gilly 17.07 image until
an explicit hardware-test decision is made.

## Pinned source

- OpenWrt: `4f2dc5cc6497a6cef0a43bdefde522e734c1f40d`
- Gilly patch repository:
  `b27c4e2a1134445db256db3417c9f784f84d6c42`
- Fanboy LuCI applications:
  `acbf82b77b96da9b62890db1e0bf82d322602ac0`
- log viewer: `69226866b51f90c35390dfe57875d56d337d8b56`
- Linux: `6.18.38`

All five OpenWrt feeds are pinned in
[`feeds.lock`](user/ubi2-hw21-bouygues/feeds.lock). The source overlay,
profile files and build hook have independent SHA-256 locks.

Detailed provenance and the two intentional local source changes are recorded
in [`UPSTREAM-SOURCES.md`](user/ubi2-hw21-bouygues/UPSTREAM-SOURCES.md).

## Network and PPE policy

The production patch policy is deliberate:

- patch `971` is present and synchronizes the IPv6 PPE source-MAC entry in
  UPDMEM with the actual offloaded flow;
- fallback patch `965` is absent, so it cannot reject IPv6 VLAN uplink flows
  before the root-cause fix runs;
- the normal dual-stack fw4 flow rule remains active;
- hardware flow offload is enabled on the first profile initialization;
- VLAN and PPPoE offload are not enabled by this profile;
- PR 24038 and `bridger` are not included.

The Gilly 19.07 `675-*` nft flowtable bridge series is retained. It is part of
the already tested Gilly data path used to discover Wi-Fi/bridge egress ports;
it is not PR 24038. Removing it would make this first v2 candidate diverge from
the known working base before hardware validation.

The workflow fails if patch `971` is missing or a `965` IPv6/VLAN fallback is
found in the applied source tree.

## Hardware and Wi-Fi

The image keeps Gilly 19.07's:

- strict RTL8261CE matcher, allowing the CE and mainline RTL8261N drivers to
  coexist in a universal source tree;
- NPU and MT7996 firmware;
- mt7996 radar `chanctx` attribution fix;
- Wi-Fi 6/6E/7 ucode behavior and EHT beamforming defaults;
- Airoha, QDMA, thermal, GRO and VLAN correctness fixes.

Full `wpad-openssl` is mandatory. `wpad-mbedtls` and all `wpad-basic-*`
variants are rejected by the policy checks. MLO and the Wi-Fi 7 LuCI panel are
included, but MLO remains disabled in the preserved production configuration.

The image adds a 64 KiB `ramoops` region at `0x86ff0000`, in the free gap before
the first QDMA reservation. The final DTB and kernel configuration are checked
after compilation.

## Included administration and tools

- FlowSense and Airoha NPU status panels
- MLO and Wi-Fi 7 panels
- full OpenSSL-backed LuCI HTTPS stack
- `dnsmasq-full` and `dnsproxy 0.83.0`
- Watchcat with a conservative migration policy
- `irqbalance` and its LuCI panel
- SQM/Cake and its LuCI panel, installed but disabled
- log viewer, fan control and OpenSSH SFTP
- `curl`, `jq`, `ip-full`, `ip-bridge`, `tc-full`, `tcpdump`, `iperf3`,
  `ethtool-full`, `arp-scan`, `fping`, WireGuard and focused diagnostics

Attended Sysupgrade, `owut`, `bridger`, `ttyd`, the LuCI file manager and the
router-hosted speed-test server are excluded.

## Recovery package

`w1700k-hw21-bouygues-support` is built into the image and owns the profile's
recovery and diagnostics files. It provides:

- post-sysupgrade restoration of `dnsproxy` and full `wpad-openssl`;
- AdGuard Unfiltered DoQ primary, NextDNS DoQ fallback and DNS.SB bootstrap;
- real hostapd/AP checks, including DFS CAC wait time;
- serialized Watchcat recovery of `wan` and `wan6` without automatic reboot;
- pstore collection without clearing crash records automatically;
- a redaction-safe `w1700k-healthcheck` command.

The Watchcat migration only replaces the exact stock `8.8.8.8`/`ping_reboot`
profile. A customized preserved Watchcat configuration is not overwritten.

`irqbalance` starts with `deepestcache=2`, a 10-second interval and no banned
CPUs or IRQs when the package default is still untouched. Packet steering is
kept disabled for the first controlled comparison.

## Build and release

Run the `build W1700K HW2.1 Bouygues` workflow. It builds only the
`ubi2-hw21-bouygues` matrix target and produces:

- the UBI2 sysupgrade ITB;
- package manifest and CycloneDX SBOM;
- OpenWrt `sha256sums` and `profiles.json`;
- effective `config.diff`;
- source, feed, container and builder provenance.

The workflow validates the assembled rootfs, kernel configuration, final DTB,
driver/firmware policy, executable modes, TLS stack, recovery files and package
manifest before creating an untested prerelease. Release assets receive GitHub
build-provenance attestations.

## Hardware gate

Before the v2 image can be called stable, a separately authorized test must
check at least:

- RTL8261CE binding on WAN and LAN2;
- WAN 10 Gbit/s and LAN2 negotiated client speed;
- normal dual-stack fw4 rule and IPv4/IPv6 `HW_OFFLOAD` flows;
- sustained IPv4 and IPv6 throughput on a 2.5G or faster client;
- all three APs, DoQ, Watchcat and pstore;
- IRQ distribution, wired/Wi-Fi throughput and latency with irqbalance;
- rollback with a known-good Gilly image.

## Historical v1

The Fanboy-based July 13 and July 14 candidates are superseded and must not be
flashed. Their audit remains in [`AUDIT-2026-07-14.md`](AUDIT-2026-07-14.md).

## Credits

Build automation is derived from
[`w1700k/fastbuild`](https://github.com/w1700k/fastbuild). The v2 kernel,
driver and Wi-Fi baseline is based on
[`Gilly1970/Gemtek-W1700K-6.18`](https://github.com/Gilly1970/Gemtek-W1700K-6.18).
The optional W1700K LuCI applications are sourced from
[`OpenWRT-fanboy/OpenW1700k`](https://github.com/OpenWRT-fanboy/OpenW1700k).
