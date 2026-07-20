# Custom v2 upstream source map

This profile is a source build based on the Gilly 19.07 universal image. It
does not modify or repack Gilly's binary firmware.

## Immutable references

| Component | Repository | Commit |
| --- | --- | --- |
| OpenWrt base | `openwrt/openwrt` | `4f2dc5cc6497a6cef0a43bdefde522e734c1f40d` |
| HW2.1/kernel/Wi-Fi patchset | `Gilly1970/Gemtek-W1700K-6.18` | `b27c4e2a1134445db256db3417c9f784f84d6c42` |
| NPU/MLO/Wi-Fi 7 LuCI applications | `OpenWRT-fanboy/OpenW1700k` | `acbf82b77b96da9b62890db1e0bf82d322602ac0` |
| Log viewer | `gSpotx2f/luci-app-log` | `69226866b51f90c35390dfe57875d56d337d8b56` |

Feed commits are stored separately in `feeds.lock`.

## Gilly overlay

Every entry selected by Gilly's `openwrt-patches/openwrt-add-patch` at the
pinned commit is copied to the same OpenWrt destination. This includes:

- RTL8261CE driver and its CE-vs-N PMA model discrimination;
- patch `971` for IPv6 UPDMEM source-MAC synchronization;
- mt7996 radar attribution, EHT, tx-power and hardening patches;
- NPU firmware and Airoha/QDMA/thermal fixes;
- Gilly's existing `675-*` nft flowtable bridge path and related Wi-Fi
  flowtable discovery hooks;
- CPU frequency support, VLAN fixes and universal UBI2 device definition.

Patch `965` is absent from Gilly's pinned 19.07 selection and is forbidden by
the builder. PR 24038 and the `bridger` package are not imported.

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
   `npu-monitor.jitter.enabled=1`. The FlowSense package release is bumped to
   carry these changes.

The custom LuCI applications and `w1700k-hw21-bouygues-support` package are
additional package directories; they do not edit the Gilly driver patches.

## Reproducibility controls

- source overlay content: `source-files.sha256`
- rootfs-only profile files: `profile-files.sha256`
- build hook: `profile-hooks.sha256`
- OpenWrt feeds: `feeds.lock`
- builder container: mirrored into this repository's GHCR namespace from the
  pinned upstream digest, then pulled and verified by digest before use
- upstream and builder commits: embedded in `/build_info`

The workflow compares these locks before `make defconfig`, rejects missing
`971` or present `965`, and checks the final kernel config and DTB after the
build. The cache seed is a best-effort performance optimization and is not a
source of files included in the firmware.
