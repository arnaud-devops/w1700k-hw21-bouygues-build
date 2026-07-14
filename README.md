# W1700K HW2.1 Bouygues build

This repository builds a focused OpenWrt image for the Gemtek W1700K HW2.1
used on a Bouygues/B&You routed connection:

- board: `gemtek,w1700k-ubi`
- target: `airoha/an7581`
- WAN: DHCP on VLAN 100
- IPv6: routed DHCPv6-PD `/60`, without NAT6
- WAN/LAN2 PHY: Realtek RTL8261CE

## Source and fix

The build pins Fanboy's audited UBI2 source commit
[`7392ce326dd6f3299dc9ddf481a4f71c759a1e61`](https://github.com/OpenWRT-fanboy/OpenW1700k/commit/7392ce326dd6f3299dc9ddf481a4f71c759a1e61).
The OpenWrt `packages`, `luci`, and `routing` feeds are pinned separately in
[`feeds.lock`](user/ubi2-hw21-bouygues/feeds.lock).

Its primary behavioral fix is the selective IPv6/VLAN PPE patch originally published as
[`ddb5d0c8ac6b8a7071a47b45fb13be3888d5d810`](https://github.com/OpenWRT-fanboy/OpenW1700k/commit/ddb5d0c8ac6b8a7071a47b45fb13be3888d5d810).
The exact kernel patch is copied into the OpenWrt source tree from the
profile's `source-files/` overlay before `make defconfig` runs.
The patch declines hardware PPE offload for IPv6 WAN-uplink flows that require
VLAN insertion. IPv4 and LAN-bound IPv6 remain eligible for PPE acceleration.

The profile also carries a small, documented set of Airoha, thermal, GRO and
mt7996 correctness fixes, a precise RTL8261CE model matcher derived from
Gilly's universal tree, plus a serialized Wi-Fi flowtable hotplug handler.
The selection, upstream status and deliberately excluded experimental work are
documented in [`AUDIT-2026-07-14.md`](AUDIT-2026-07-14.md).

## Included profile

The `ubi2-hw21-bouygues` profile keeps Fanboy's full UBI2 package selection
and explicitly includes:

- `wpad-openssl` for the preserved 802.11k/v Wi-Fi configuration
- `dnsmasq-full`
- `dnsproxy` with DNS-over-QUIC support
- a boot and WAN recovery service for dnsproxy and full wpad

Generic Attended Sysupgrade and `owut` are intentionally omitted because they
cannot reproduce this pinned custom patchset. The workflow also avoids
`CONFIG_ALL_KMODS`; it validates all required device packages against the final
image manifest instead.

The image does not force the official buildbot kernel `vermagic` and does not
expose the generic OpenWrt `kmods` feed. All required kernel modules are built
with this patched kernel and embedded in the image. The remaining userspace
APK repository list is pinned with the profile. A dedicated cache epoch forces
one clean target rebuild when this native-ABI policy is introduced.

The recovery policy configures AdGuard Unfiltered DoQ as primary, NextDNS DoQ
as fallback, and DNS.SB port 53 addresses only as bootstrap/recovery resolvers.

No router backup, Wi-Fi credential, MAC address, DUID, public address, capture,
or other device-specific configuration is stored in this repository.

## Build

Run the `build W1700K HW2.1 Bouygues` workflow from GitHub Actions. It builds
only `ubi2-hw21-bouygues` and creates a prerelease containing:

- the UBI2 sysupgrade ITB
- the package manifest
- `sha256sums`
- `profiles.json`
- the effective `config.diff`
- source, feed and builder provenance in `build-info.txt`

The workflow aborts if the checked-out OpenWrt commit differs from the pinned
commit, if a feed differs from its lock, or if any source overlay differs from
`source-files.sha256`. Profile files are independently checked against
`profile-files.sha256`. It fetches the immutable source commit explicitly so a
later UBI2 branch rebase cannot make a cached checkout accidentally determine
the build result.
The complete staged output is also retained as a GitHub Actions artifact for
14 days before release creation, so a publication error does not discard a
successful firmware build.

## First candidate (superseded for further testing)

The first candidate was built successfully before the 2026-07-14 hardening by
[workflow run 29290389340](https://github.com/arnaud-devops/w1700k-hw21-bouygues-build/actions/runs/29290389340)
and published as the prerelease
[`ubi2-hw21-bouygues_2026.07.13_r0+35355-271d907218_3b43508`](https://github.com/arnaud-devops/w1700k-hw21-bouygues-build/releases/tag/ubi2-hw21-bouygues_2026.07.13_r0%2B35355-271d907218_3b43508).

The sysupgrade image is 25,695,055 bytes and has SHA-256:

```text
1d7ca1959a5c2c8e83ff18219058567a7b53bc7c68bb262625bae241575d2074
```

The release checksum, FIT contents, sysupgrade metadata, package manifest and
extracted rootfs have been checked independently. The image contains the
RTL8261CE module/firmware, MT7996/NPU firmware, `wpad-openssl`, `dnsproxy`,
`dnsmasq-full`, and the exact recovery files from this repository. It has not
yet been flashed on hardware and remains a candidate until post-sysupgrade
WAN, LAN2, three-band Wi-Fi, DoQ and IPv4/IPv6 PPE tests pass. A newer hardened
candidate must pass the same offline and hardware gates before replacing it.

## Validation before flashing

Verify the release checksum and run OpenWrt's image metadata and compatibility
checks before any sysupgrade. Keep the known-good Gilly image and the Fanboy
blackhole image available for rollback. Building or publishing this image does
not authorize an automatic router flash.

After flashing, validate the RTL8261CE binding, WAN 10G link, all three Wi-Fi
APs, DoQ resolution, the normal IPv4+IPv6 fw4 flowtable rule, and sustained
IPv4/IPv6 transfers from a 2.5G or faster wired client.

## Credits

Build automation is derived from [`w1700k/fastbuild`](https://github.com/w1700k/fastbuild).
The OpenWrt tree is maintained by
[`OpenWRT-fanboy/OpenW1700k`](https://github.com/OpenWRT-fanboy/OpenW1700k),
and the selective PPE fix was developed by Gilly1970 and validated on a
W1700K HW2.1.
