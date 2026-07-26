# W1700K HW2.1 Bouygues custom v2.3

This repository builds a pinned OpenWrt image for the Gemtek W1700K HW2.1
used on a Bouygues/B&You routed connection:

- target: `airoha/an7581`
- image profile: `gemtek_w1700k-ubi2`
- WAN PHY: Realtek RTL8261CE
- WAN: DHCP on VLAN 100
- IPv6: routed DHCPv6-PD `/60`, without NAT6

The v2.3 source profile is based on Gilly's 21.07 universal build. It is
compiled from source; the binary image from Gilly is not repackaged.

## Status

The v2.3 candidate adds Fanboy's general-purpose administration and
post-install kernel-module policy to the audited v2.2 network base. It was
built, published and independently audited offline on 2026-07-26. No custom
image has been flashed.

The v2.3 release remains labelled:

```text
[UNTESTED ON HW2.1 - DO NOT FLASH YET]
```

The previous v2.2 candidate is superseded but remains available as the
narrower offline-audited image without the Fanboy package-management and
administration additions.

Building or publishing an image does not authorize an automatic router flash.
No workflow in this repository connects to the router.

The active router remains on the separately validated Gilly 17.07 image until
an explicit hardware-test decision is made.

- [GitHub Actions run 30179972239](https://github.com/arnaud-devops/w1700k-hw21-bouygues-build/actions/runs/30179972239)
- [Untested v2.3 prerelease](https://github.com/arnaud-devops/w1700k-hw21-bouygues-build/releases/tag/ubi2-hw21-bouygues_2026.07.26_r0%2B35485-0f256a0a7a_54edeb5)
- [Independent v2.3 audit](AUDIT-2026-07-26-V2.3.md)
- [v2.3 Fanboy tools and compatibility policy](V2.3-FANBOY-TOOLS-POLICY.md)
- [Superseded v2.2 audit](AUDIT-2026-07-25-V2.2.md)

## Pinned source

- OpenWrt: `0f256a0a7adf5741e4a061f59a08cd01c14dc526`
- Gilly patch repository:
  `e6a4cdcbb05a486dba8871466baa014dd5d97a95`
- Fanboy LuCI applications:
  `acbf82b77b96da9b62890db1e0bf82d322602ac0`
- log viewer: `69226866b51f90c35390dfe57875d56d337d8b56`
- Linux: `6.18.39`

All five OpenWrt feeds are pinned in
[`feeds.lock`](user/ubi2-hw21-bouygues/feeds.lock). The source overlay,
profile files and build hook have independent SHA-256 locks.

Detailed provenance and the seven intentional local source changes are recorded
in [`UPSTREAM-SOURCES.md`](user/ubi2-hw21-bouygues/UPSTREAM-SOURCES.md).

## Network and PPE policy

The production patch policy is deliberate:

- patch `972` synchronizes the IPv6 PPE source-MAC entry in UPDMEM with the
  actual offloaded flow;
- patch `973` allocates, references and locks UPDMEM slots per source MAC,
  falling back only an individual flow if no safe slot is available;
- superseded patch `971` is absent;
- fallback patch `965` is absent, so it cannot reject IPv6 VLAN uplink flows
  before the root-cause fix runs;
- the normal dual-stack fw4 flow rule remains active;
- hardware flow offload is enabled on the first profile initialization;
- VLAN and PPPoE offload are not enabled by this profile;
- PR 24038 and `bridger` are not included.

The Gilly 21.07 `675-*` nft flowtable bridge series is retained. It is part of
the already tested Gilly data path used to discover Wi-Fi/bridge egress ports;
it is not PR 24038. Removing it would make the v2.3 candidate diverge from the
known working base before hardware validation.

The workflow fails if `972` or `973` is missing, or if superseded `971` or a
`965` IPv6/VLAN fallback is found in the applied source tree.

## Hardware and Wi-Fi

The image keeps Gilly 21.07's:

- RTL8261CE PMA model check, allowing CE model `0x9` and RTL8261N model `0x2f`
  to be distinguished in a universal source tree; v2.2 also preserves
  phylib's generic Realtek vendor/model guard;
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

## Kernel module installation policy

The v2.3 profile deliberately enables `CONFIG_ALL_KMODS` and Fanboy's forced
buildbot-vermagic mechanism. The exact hash is pinned to:

```text
7a95fc2977560f4c28e39a71bf89c960
```

The matching Linux 6.18.39 release-1 Airoha kmods repository is embedded as an
exact URL instead of downloading a moving hash during CI. This preserves build
reproducibility while allowing APK and LuCI to offer official OpenWrt
`kmod-*` packages.

All modules preinstalled in the firmware are still compiled from the pinned
locally patched source. A later official `kmod-*` installation is an explicitly
accepted compatibility risk: the forced package hash does not prove ABI
identity with the RTL8261CE, Airoha PPE, bridge or MT7996 patches. Rebuild this
profile when a new module is operationally important.

The exact public kmods path belongs to OpenWrt snapshots and is not guaranteed
to remain online indefinitely. `CONFIG_ALL_KMODS` compiles the packages but
this release does not claim to host a permanent custom APK repository. The
unrelated Telephony `kmod-ipt-rtpengine` is the sole explicit exception because
its pinned feed revision cannot compile against Linux 6.18.39
(`xt_RTPENGINE.h` is absent). Use targeted `apk add` transactions only; never
bulk-upgrade the image from LuCI or with `apk upgrade`.

## Included administration and tools

- FlowSense 1.1.4 and Airoha NPU status panels
- FlowSense jitter probe installed but disabled by default
- MLO and Wi-Fi 7 panels
- full OpenSSL-backed LuCI HTTPS stack
- `dnsmasq-full` and `dnsproxy 0.83.0`
- Watchcat with a conservative migration policy
- `irqbalance` and its LuCI panel
- SQM/Cake and its LuCI panel, installed but disabled
- log viewer, fan control and OpenSSH SFTP
- Attended Sysupgrade and `owut`
- Dropbear SSH plus LAN-bound, TLS-enabled `ttyd` Web terminal
- LuCI file manager and LuCI APK package manager
- browser-side nPerf, LibreSpeed backend and LuCI speed-test panel, with
  router-hosted servers disabled at boot
- `curl`, `jq`, BusyBox `flock`, `ip-full`, `ip-bridge`, `tc-full`, `tcpdump`,
  `iperf3`, `ethtool-full`, `arp-scan`, `fping`, WireGuard and focused
  diagnostics

`bridger`, Fanboy's separate GitHub download CGI helpers, `relayd`, `fastfetch`
and duplicate mbedTLS packages remain excluded.

Attended Sysupgrade and `owut` do not reproduce this repository's pinned
Gilly/Fanboy patches or support package on the public OpenWrt build service.
They are included as explicit administrative tools, not as the recommended
upgrade path. The checksum-verified workspace sysupgrade procedure remains the
only supported path for preserving the complete custom policy.

The optional FlowSense latency metric can be enabled explicitly with:

```sh
uci set npu-monitor.jitter.enabled='1'
uci commit npu-monitor
/etc/init.d/npu-jitter restart
```

Leaving the option at `0` keeps the daemon stopped and sends no periodic
probe.

## Recovery package

`w1700k-hw21-bouygues-support` is built into the image and owns the profile's
recovery and diagnostics files. It provides:

- post-sysupgrade restoration of `dnsproxy` and full `wpad-openssl`;
- AdGuard Unfiltered DoQ primary, NextDNS DoQ fallback and DNS.SB bootstrap;
- real `hostapd.*` and AP-netdev checks, including DFS CAC wait time, with
  `flock` serialization;
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
driver/firmware policy, executable modes, TLS stack, recovery files, pinned
vermagic/kmods tuple, LAN-only ttyd policy, disabled LibreSpeed default and
package manifest before creating an untested prerelease. Release assets receive
GitHub build-provenance attestations.

The v2.3 image is 27,513,758 bytes and has SHA-256
`8a114d40e3d19b302b2b0bd53cd710098651196a774c0ae667233f78265a1baf`.
The v2.2 and corrected v2.1 images are superseded but remain available as
narrower offline-audited candidates. The first v2 image is also superseded;
its findings remain in [`AUDIT-2026-07-20.md`](AUDIT-2026-07-20.md).

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
