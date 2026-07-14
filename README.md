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
mt7996 correctness fixes, including the upstream-proposed per-radio DT MAC
export, a precise RTL8261CE model matcher derived from Gilly's universal tree,
plus a serialized Wi-Fi flowtable hotplug handler. A profile-level source
patch also preserves the active Gilly image's 6 GHz in-band discovery and EHT
beamforming defaults in the actual `wifi-scripts` ucode files.
The selection, upstream status and deliberately excluded experimental work are
documented in [`AUDIT-2026-07-14.md`](AUDIT-2026-07-14.md).

## Included profile

The `ubi2-hw21-bouygues` profile deliberately does not inherit Fanboy's full
demonstration package set. It stays close to the package and service surface
already validated on the deployed router and explicitly includes:

- `wpad-openssl` for the preserved 802.11k/v Wi-Fi configuration
- `dnsmasq-full`
- `dnsproxy` with DNS-over-QUIC support
- `ethtool-full` for RTL8261CE link and PHY diagnostics
- OpenSSL-backed APK, LuCI HTTPS and ustream TLS, without the duplicate
  mbedTLS userspace stack; the OpenSSL legacy provider remains because full
  `wpad-openssl` requires it for its EAP/RADIUS feature set
- the existing Watchcat configuration, LuCI log viewer and SFTP server used by
  the guarded Mac upgrade workflow
- `arp-scan`, `fping` and `iperf3` for focused LAN/WAN diagnostics
- a boot and WAN recovery service for dnsproxy and full wpad

Generic Attended Sysupgrade and `owut` are intentionally omitted because they
cannot reproduce this pinned custom patchset. The workflow also avoids
`CONFIG_ALL_KMODS`; it validates all required device packages against the final
image manifest instead.

The generic `irqbalance`, `ttyd`, LuCI file manager, router-hosted speedtest,
MLO/Wi-Fi 7 tuning panels and NPU overclock/configuration panel are also left
out. They are not required by the current routed configuration; some would
change a validated IRQ policy or expose additional privileged administration
surfaces. FlowSense and the W1700K fan-control pages remain included.

The log viewer is vendored from
[`gSpotx2f/luci-app-log@69226866`](https://github.com/gSpotx2f/luci-app-log/commit/69226866b51f90c35390dfe57875d56d337d8b56),
the exact source used by the active Gilly image. Its files and MIT license are
covered by the profile source checksum lock. The later upstream `r3` is not
used because it disables log-message HTML escaping while the renderer still
uses `insertAdjacentHTML()`; the audited `r2` keeps that escaping in place.

The inherited web CGI helpers that fetch generic `w1700k/builds` images are
also removed. Upgrades for this profile go through the checksum-verified local
workflow only; the unrelated single-wiphy LuCI display fix remains included.

The image does not force the official buildbot kernel `vermagic` and does not
expose the generic OpenWrt `kmods` feed. All required kernel modules are built
with this patched kernel and embedded in the image. The restricted runtime APK
repository list is versioned with the profile and omits the unused telephony
and video indexes; snapshot contents remain rolling by design. A dedicated
cache epoch forces one clean target rebuild when this native-ABI policy is
introduced.

The recovery policy configures AdGuard Unfiltered DoQ as primary, NextDNS DoQ
as fallback, and DNS.SB port 53 addresses only as bootstrap/recovery resolvers.
At first boot, the profile restores its audited recovery scripts from `/rom`
before enabling them, so an older copy preserved by `/etc/sysupgrade.conf`
cannot mask a fix in the new image. The recovery job uses a kernel-held
`flock` lock that cannot remain stale after an interrupted process.

No router backup, Wi-Fi credential, MAC address, DUID, public address, capture,
or other device-specific configuration is stored in this repository.

## Build

Run the `build W1700K HW2.1 Bouygues` workflow from GitHub Actions. It builds
only `ubi2-hw21-bouygues` and creates a prerelease containing:

- the UBI2 sysupgrade ITB
- the package manifest
- the OpenWrt CycloneDX SBOM
- `sha256sums`
- `profiles.json`
- the effective `config.diff`
- source, feed and builder provenance in `build-info.txt`

The workflow aborts if the checked-out OpenWrt commit differs from the pinned
commit, if a feed differs from its lock, or if any source overlay differs from
`source-files.sha256`. Rootfs profile files and the profile hook are checked
independently against `profile-files.sha256` and `profile-hooks.sha256`.
Profile-level OpenWrt source patches are covered by
`profile-patches.sha256`. It fetches the immutable source commit explicitly so
a later UBI2 branch rebase cannot make a cached checkout accidentally
determine the build result.
The GitHub Actions and both upstream build/cache containers are pinned by
immutable commit or image digest. No mutable incremental builder image is
loaded or published; the selected container digest is recorded in
`build-info.txt`. The inherited daily GHCR cleanup workflow is removed because
this repository no longer publishes mutable builder images; keeping its broad
write permission and unpinned actions would serve no purpose.
Before publishing, it also inspects the assembled rootfs for the required
drivers, firmware, recovery files and executable modes, and rejects generic
kernel feeds or upgrade/download helpers.
The workflow creates a GitHub build-provenance attestation for the sysupgrade
ITB before publishing it. It can be checked independently with
`gh attestation verify IMAGE --repo arnaud-devops/w1700k-hw21-bouygues-build`.
The complete staged output is also retained as a GitHub Actions artifact for
14 days before release creation, so a publication error does not discard a
successful firmware build.

## First candidate (superseded; do not flash)

The first candidate was built successfully before the 2026-07-14 hardening by
[workflow run 29290389340](https://github.com/arnaud-devops/w1700k-hw21-bouygues-build/actions/runs/29290389340)
and published as the prerelease
[`ubi2-hw21-bouygues_2026.07.13_r0+35355-271d907218_3b43508`](https://github.com/arnaud-devops/w1700k-hw21-bouygues-build/releases/tag/ubi2-hw21-bouygues_2026.07.13_r0%2B35355-271d907218_3b43508).

The sysupgrade image is 25,695,055 bytes and has SHA-256:

```text
1d7ca1959a5c2c8e83ff18219058567a7b53bc7c68bb262625bae241575d2074
```

The release checksum, FIT contents, sysupgrade metadata and core network files
were checked independently. A later package-policy review found that this
image still inherited generic packages such as Attended Sysupgrade, `ttyd` and
`irqbalance`, while omitting Watchcat, the deployed log viewer and the SFTP
server used by the upgrade workflow. It must not be flashed. A newer lean
candidate must pass both the package-policy checks and the same offline and
hardware gates before replacing it.

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
