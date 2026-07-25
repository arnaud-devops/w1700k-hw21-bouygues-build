# Custom v2.3 upstream source map

This profile is a source build based on the Gilly 21.07 universal image. It
does not modify or repack Gilly's binary firmware.

## Immutable references

| Component | Repository | Commit |
| --- | --- | --- |
| OpenWrt base | `openwrt/openwrt` | `0f256a0a7adf5741e4a061f59a08cd01c14dc526` |
| HW2.1/kernel/Wi-Fi patchset | `Gilly1970/Gemtek-W1700K-6.18` | `e6a4cdcbb05a486dba8871466baa014dd5d97a95` |
| NPU/MLO/Wi-Fi 7 LuCI applications | `OpenWRT-fanboy/OpenW1700k` | `acbf82b77b96da9b62890db1e0bf82d322602ac0` |
| Fanboy forced-vermagic reference | `OpenWRT-fanboy/OpenW1700k` | `0abbad3617e535870438189381261bb63a8060e8` |
| Log viewer | `gSpotx2f/luci-app-log` | `69226866b51f90c35390dfe57875d56d337d8b56` |

Feed commits are stored separately in `feeds.lock`.

## Gilly overlay

Every entry selected by Gilly's `openwrt-patches/openwrt-add-patch` at the
pinned commit is copied to the same OpenWrt destination. This includes:

- RTL8261CE driver and its CE-vs-N PMA model discrimination;
- patch `972` for IPv6 UPDMEM source-MAC synchronization;
- patch `973` for refcounted per-MAC UPDMEM slot allocation and locking;
- mt7996 radar attribution, EHT, tx-power and hardening patches;
- NPU firmware and Airoha/QDMA/thermal fixes;
- Gilly's existing `675-*` nft flowtable bridge path and related Wi-Fi
  flowtable discovery hooks;
- CPU frequency support, VLAN fixes and universal UBI2 device definition.

Superseded patch `971` and selective fallback patch `965` are absent from
Gilly's pinned 21.07 selection and are forbidden by the builder. PR 24038 and
the `bridger` package are not imported.

## Intentional local source changes

Seven Gilly-provided source files differ by content:

1. `target/linux/airoha/dts/an7581.dtsi`

   Adds a 64 KiB `ramoops` node at `0x86ff0000`. The region ends exactly at
   `0x87000000`, where Gilly's first QDMA reservation begins.

2. `target/linux/airoha/an7581/config-6.18`

   Enables `PSTORE`, RAM backend, console and pmsg capture for that node.

3. `package/luci-app-airoha-flowsense/Makefile`

4. `package/luci-app-w1700k-fancontrol/Makefile`

   These two applications retain Gilly's content. Their `luci.mk` include is
   changed to `$(TOPDIR)/feeds/luci/luci.mk` because this builder installs
   custom applications under `package/`, while Gilly's helper places them in
   `feeds/luci/applications/`.

5. `target/linux/generic/files/drivers/net/phy/rtl8261ce/rtk_rtl8261ce_phy.c`

   Preserves phylib's generic Realtek vendor/model match before applying
   Gilly's PMA/PMD CE-model check. A custom callback otherwise replaces the
   generic PHY-ID matcher instead of augmenting it.

6. `package/luci-app-airoha-flowsense/root/etc/config/npu-monitor`

7. `package/luci-app-airoha-flowsense/root/etc/init.d/npu-jitter`

   Make the permanent two-second external jitter probe opt-in. The service
   remains installed for FlowSense but starts its daemon only when
   `npu-monitor.jitter.enabled=1`. Named and legacy anonymous UCI sections are
   supported, while FlowSense 1.1.4's atomic writes and real mt76 per-band Tx
   PER metric are retained.

The custom LuCI applications and `w1700k-hw21-bouygues-support` package are
additional package directories; they do not edit the Gilly driver patches.
The v2.3 source overlay also vendors Fanboy's `luci-app-netspeedtest` package
from the pinned application commit. Its declared dependencies select `iperf3`,
`librespeed-go`, `ca-certificates` and `curl`. The local delta:

- makes two init-script expressions POSIX-safe (`=` instead of `==`, and an
  explicit `if` instead of `A && B || C`);
- exposes the official nPerf website in the browser-side client panel;
- restricts RPC methods that download or execute speed tests to LuCI write
  permission, leaving only status verification in the read ACL;
- validates the prepare-script arguments and path quoting;
- restricts the optional Ookla path to this target's `aarch64` architecture
  and the official `install.speedtest.net` URL pattern;
- quotes the Ookla RPC arguments, uses explicit proxy construction, extracts
  only the expected `speedtest` archive member into a temporary file, and
  executes `--version` before installation.

The optional Ookla CLI remains an explicit interactive download over HTTPS; it
is not present in the immutable image. nPerf runs in the administrator's
browser rather than as a native executable on the router.

## Fanboy general-purpose build policy

`patches/0001-build-support-pinned-buildbot-vermagic.patch` reproduces the two
relevant build-system changes from Fanboy commit `0abbad3617e5`: generation of
the target kmods repository outside buildbot jobs and optional replacement of
the locally computed `.vermagic` with `files/etc/vermagic.txt`.

The profile deliberately enables `CONFIG_ALL_KMODS`, with only
`kmod-ipt-rtpengine` disabled because the unrelated SIP media-proxy module in
the pinned Telephony feed cannot compile against Linux 6.18.39 due to its
missing `xt_RTPENGINE.h` header. The buildbot hash
`7a95fc2977560f4c28e39a71bf89c960` and its Linux
`6.18.39-1` Airoha repository URL are stored and checksummed locally rather
than fetched dynamically from `w1700k.github.io`. This makes repeated builds
of the same builder commit deterministic.

The support package owns the identical runtime `/etc/vermagic.txt` without
marking it as a conffile, avoiding its preservation as user configuration when
moving to an unrelated image.

The policy does not turn official post-installed modules into locally built
modules. It only makes APK accept their kernel package dependency. Every
module preinstalled in the image still comes from the pinned patched source;
official `kmod-*` packages added later retain an explicit ABI risk.

The profile additionally installs official Attended Sysupgrade, `owut`,
LAN-bound TLS-enabled `ttyd`, the LuCI file and package managers, and
LibreSpeed. It keeps the custom DoQ, Watchcat, Wi-Fi recovery, SFTP and
diagnostics. LibreSpeed is disabled by its package default, and the workflow
verifies both that setting and ttyd's `@lan` `/bin/login` policy.

## Reproducibility controls

- source overlay content: `source-files.sha256`
- rootfs-only profile files: `profile-files.sha256`
- build hook: `profile-hooks.sha256`
- direct OpenWrt build-system patch: `profile-patches.sha256`
- OpenWrt feeds: `feeds.lock`
- builder container: mirrored into this repository's GHCR namespace from the
  pinned upstream digest, then pulled and verified by digest before use
- upstream and builder commits: embedded in `/build_info`

The workflow compares these locks before `make defconfig`, rejects missing
`972`/`973`, rejects superseded `971` or fallback `965`, and checks the final
kernel config and DTB after the build. The UBI2 profile explicitly selects the
W1700K U-Boot package and the workflow verifies its compressed image and DTB
before image generation; this avoids relying on a chainloader file inherited
from a build cache. The cache seed is a best-effort performance optimization
and is not a source of files included in the firmware.
