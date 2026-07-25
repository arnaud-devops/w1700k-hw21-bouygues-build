#!/bin/bash

set -euo pipefail

# This profile has no generic online-upgrade client. Do not expose inherited
# helpers that download unrelated images or overwrite the pinned Gilly patch.
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

patch_dir=target/linux/airoha/patches-6.18
patch_972="$patch_dir/972-net-airoha-sync-UPDMEM-source-MAC-for-offloaded-IPv6.patch"
patch_973="$patch_dir/973-net-airoha-UPDMEM-slot-allocator-for-IPv6-source-MACs.patch"

for patch in "$patch_972" "$patch_973"; do
	[ -s "$patch" ] || {
		echo "missing required IPv6 UPDMEM patch: $patch" >&2
		exit 1
	}
done

if find "$patch_dir" -type f -name '971-*UPDMEM*' | grep -q .; then
	echo "superseded IPv6 UPDMEM patch 971 is present" >&2
	exit 1
fi

if find target/linux -type f -name '*965*ipv6*vlan*' | grep -q .; then
	echo "forbidden selective fallback patch 965 is present" >&2
	exit 1
fi

[ -s package/kernel/mt76/patches/020-wifi-mt76-mt7996-report-radar-on-detecting-chanctx.patch ] || {
	echo "missing mt7996 radar chanctx patch" >&2
	exit 1
}

grep -Fq '!genphy_match_phy_device(phydev, phydrv)' \
	target/linux/generic/files/drivers/net/phy/rtl8261ce/rtk_rtl8261ce_phy.c || {
	echo "RTL8261CE generic vendor/model guard is missing" >&2
	exit 1
}

recovery=package/w1700k-hw21-bouygues-support/files/usr/local/sbin/restore-dnsproxy-after-sysupgrade
grep -Fq 'ubus call "$hostapd_object" get_status' "$recovery" || {
	echo "hostapd-aware Wi-Fi recovery check is missing" >&2
	exit 1
}

grep -Eq "^[[:space:]]*option enabled .0.$" package/luci-app-airoha-flowsense/root/etc/config/npu-monitor || {
	echo "FlowSense jitter probe is not disabled by default" >&2
	exit 1
}
grep -Fq 'npu-monitor.jitter.enabled' \
	package/luci-app-airoha-flowsense/root/etc/init.d/npu-jitter || {
	echo "FlowSense jitter service does not enforce its opt-in policy" >&2
	exit 1
}

grep -Fq 'ramoops@86ff0000' target/linux/airoha/dts/an7581.dtsi || {
	echo "64 KiB ramoops reservation is missing" >&2
	exit 1
}
