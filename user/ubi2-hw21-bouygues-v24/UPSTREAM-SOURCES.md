# V2.4 source policy

The v2.4 image is built from Hurryman's immutable 25.07 source commit:

- repository: `https://github.com/hurryman2212/OpenW1700k-test`
- commit: `2d02d62666bd8f6ef89b193238c58984db592330`
- corresponding release:
  `ubi2-oc-offload_2026.07.25_r35578-2d02d62666`

The profile keeps the W1700K hardware, Wi-Fi, RTL8261CE, NPU, bridge-flow and
reassociation fixes from that source. It deliberately removes the unrelated
experimental SOE/XFRM/LAG series, restores stock CPU limits and an adaptive
governor, and leaves hardware LRO available but disabled by default.

The routed IPv6 source-MAC fix is Gilly's `972` plus the experimental
refcounted UPDMEM allocator `973`. Patches `965` and `971` are forbidden.

The bridge kernel path comes from the Hurryman release. Its userspace rules are
replaced with a fw4-aware implementation derived from the architecture of
OpenWrt PR 24038. Bridge offload has an independent UCI gate and is disabled
by default; routed flow offload remains enabled.

All feeds, GitHub Actions and builder images are pinned. Feed commits are not
newer than the immutable Hurryman source. Two checksum-locked, build-time-only
metadata fixes remove known Kconfig cycles in unused FreeRADIUS and
trafficshaper package definitions; neither package is installed in the image.
The build keeps `nftables-json`, uses its native kernel ABI and publishes its
own matching APK repository. It never forces the public OpenWrt buildbot
vermagic.
