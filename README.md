# W1700K HW2.1 Bouygues build

This repository builds a focused OpenWrt image for the Gemtek W1700K HW2.1
used on a Bouygues/B&You routed connection:

- board: `gemtek,w1700k-ubi`
- target: `airoha/an7581`
- WAN: DHCP on VLAN 100
- IPv6: routed DHCPv6-PD `/60`, without NAT6
- WAN/LAN2 PHY: Realtek RTL8261CE

## Source and fix

The build pins Fanboy's UBI2 source commit
[`271d907218b2e8fbaebd3fa2694f8b1467b3de28`](https://github.com/OpenWRT-fanboy/OpenW1700k/commit/271d907218b2e8fbaebd3fa2694f8b1467b3de28).
The OpenWrt `packages`, `luci`, and `routing` feeds are pinned separately in
[`feeds.lock`](user/ubi2-hw21-bouygues/feeds.lock).

It adds only the selective IPv6/VLAN PPE patch originally published as
[`ddb5d0c8ac6b8a7071a47b45fb13be3888d5d810`](https://github.com/OpenWRT-fanboy/OpenW1700k/commit/ddb5d0c8ac6b8a7071a47b45fb13be3888d5d810).
The exact kernel patch is copied into the OpenWrt source tree from the
profile's `source-files/` overlay before `make defconfig` runs.
The patch declines hardware PPE offload for IPv6 WAN-uplink flows that require
VLAN insertion. IPv4 and LAN-bound IPv6 remain eligible for PPE acceleration.

## Included profile

The `ubi2-hw21-bouygues` profile keeps Fanboy's full UBI2 package selection
and explicitly includes:

- `wpad-openssl` for the preserved 802.11k/v Wi-Fi configuration
- `dnsmasq-full`
- `dnsproxy` with DNS-over-QUIC support
- a boot and WAN recovery service for dnsproxy and full wpad

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
commit, if a feed differs from its lock, or if the selective patch is missing.

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
