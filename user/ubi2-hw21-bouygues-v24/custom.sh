#!/bin/bash

set -euo pipefail

# Shared fastbuild defaults contain developer helpers that are intentionally
# excluded from the production image.
rm -f \
	files/998-single-wiphy.patch \
	files/overview.js \
	files/etc/fe_debug_reg.sh \
	files/etc/fe_reg.sh \
	files/etc/gsw_status.sh \
	files/etc/md.sh \
	files/etc/testgpio.sh \
	files/etc/xsi_mac_dbg.sh \
	files/www/cgi-bin/github_check \
	files/www/cgi-bin/github_fetch

# Hurryman's SOE/XFRM/LAG series and its mt76 callback companion are unrelated
# to this routed WAN use case and substantially increase the untested kernel
# surface. Verify the exact pinned source before removing them so upstream
# drift cannot silently change policy.
excluded_lock="$DK_PROFILE/excluded-patches.sha256"
[ -s "$excluded_lock" ] || {
	echo "missing excluded patch checksum lock: $excluded_lock" >&2
	exit 1
}
sha256sum -c "$excluded_lock"
while read -r _ patch; do
	[ -n "$patch" ] || continue
	rm -f "$patch"
done < "$excluded_lock"
[ "$(wc -l < "$excluded_lock")" -eq 47 ] || {
	echo "unexpected SOE/XFRM/LAG exclusion count" >&2
	exit 1
}
if find target/linux/airoha -type f -name '9999-*' | grep -q .; then
	echo "an unreviewed Airoha 9999 experimental patch remains" >&2
	exit 1
fi
if [ -e package/kernel/mt76/patches/9993-wifi-mt76-distinguish-flowtable-callbacks.patch ]; then
	echo "the SOE flowtable-context mt76 companion remains" >&2
	exit 1
fi
airoha_eth_package=$(sed -n \
	'/^define KernelPackage\/airoha-eth$/,/^endef$/p' \
	package/kernel/linux/modules/netdevices.mk)
if grep -Eq 'NET_AIROHA_SOE|kmod-ipsec4-offload' <<< "$airoha_eth_package"; then
	echo "the production Airoha Ethernet package still forces SOE/IPsec" >&2
	exit 1
fi

patch_dir=target/linux/airoha/patches-6.18
for patch in \
	"$patch_dir/972-net-airoha-sync-UPDMEM-source-MAC-for-offloaded-IPv6.patch" \
	"$patch_dir/973-net-airoha-UPDMEM-slot-allocator-for-IPv6-source-MACs.patch"; do
	[ -s "$patch" ] || {
		echo "missing required IPv6 UPDMEM patch: $patch" >&2
		exit 1
	}
done

if find "$patch_dir" -type f -name '971-*UPDMEM*' | grep -q .; then
	echo "superseded IPv6 UPDMEM patch 971 is present" >&2
	exit 1
fi
if find target/linux -type f -iname '*965*ipv6*vlan*' | grep -q .; then
	echo "selective IPv6 software fallback patch 965 is present" >&2
	exit 1
fi

for bridge_patch in \
	target/linux/generic/pending-6.18/675-01-net-forward-path-exports-and-bridge-helper.patch \
	target/linux/generic/pending-6.18/675-02-net-bridge-forward-path-helpers-and-vlan-modes.patch \
	target/linux/generic/pending-6.18/675-03-nft_flow_offload-add-bridging-support.patch \
	target/linux/generic/pending-6.18/675-04-netfilter-nf_flow_table-add-bridge-flowtable-type.patch \
	target/linux/generic/pending-6.18/675-05-netfilter-bridge-Add-conntrack-double-vlan-pppoe.patch \
	target/linux/generic/pending-6.18/700-netfilter-nft_flow_offload-handle-netdevice-events-f.patch \
	target/linux/generic/pending-6.18/701-netfilter-nf_tables-ignore-EOPNOTSUPP-on-flowtable-d.patch \
	target/linux/airoha/patches-6.18/990-01-netfilter-nf_flow_table-invalidate-flows-on-bridge-FDB-roaming.patch \
	target/linux/airoha/patches-6.18/990-02-airoha-ppe-invalidate-bridge-flows-on-teardown.patch \
	target/linux/airoha/patches-6.18/9990-net-airoha-bind-WLAN-bound-flows-on-PPE-driver-L2-cache-miss.patch \
	package/kernel/mac80211/patches/subsys/990-mac80211-emit-switchdev-fdb-del-on-sta-disconnect.patch; do
	[ -s "$bridge_patch" ] || {
		echo "missing reviewed bridge offload patch: $bridge_patch" >&2
		exit 1
	}
done

[ -s package/network/config/firewall4/patches/001-add-bridge-flowtable-support.patch ] || {
	echo "missing gated firewall4 bridge flowtable integration" >&2
	exit 1
}
[ -s package/kernel/mt76/patches/020-wifi-mt76-mt7996-report-radar-on-detecting-chanctx.patch ] || {
	echo "missing mt7996 radar chanctx patch" >&2
	exit 1
}
grep -Fq '!genphy_match_phy_device(phydev, phydrv)' \
	target/linux/generic/files/drivers/net/phy/rtl8261ce/rtk_rtl8261ce_phy.c || {
	echo "RTL8261CE Clause 45 and PMA model binding guard is missing" >&2
	exit 1
}

recovery=package/w1700k-hw21-bouygues-support/files/usr/local/sbin/restore-dnsproxy-after-sysupgrade
# shellcheck disable=SC2016
grep -Fq 'ubus call "$hostapd_object" get_status' "$recovery" || {
	echo "hostapd-aware Wi-Fi recovery check is missing" >&2
	exit 1
}
grep -Eq "^[[:space:]]*option enabled .0.$" \
	package/luci-app-airoha-flowsense/root/etc/config/npu-monitor || {
	echo "FlowSense jitter probe is not disabled by default" >&2
	exit 1
}
grep -Fq 'npu-monitor.jitter.enabled' \
	package/luci-app-airoha-flowsense/root/etc/init.d/npu-jitter || {
	echo "FlowSense jitter service does not enforce opt-in" >&2
	exit 1
}
grep -Fq 'ramoops@86ff0000' target/linux/airoha/dts/an7581.dtsi || {
	echo "64 KiB ramoops reservation is missing" >&2
	exit 1
}

if grep -Fq '../../../files/etc/vermagic.txt' include/kernel-defaults.mk; then
	echo "forced buildbot kernel vermagic hook remains" >&2
	exit 1
fi
apk_feed_block=$(sed -n '/define FeedSourcesAppendAPK/,/endef/p' include/feeds.mk)
if grep -Fq 'targets/%S/kmods/' <<< "$apk_feed_block"; then
	echo "official buildbot kmods feed hook remains" >&2
	exit 1
fi
