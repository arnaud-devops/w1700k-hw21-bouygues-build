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
patch_971="$patch_dir/971-net-airoha-sync-UPDMEM-source-MAC-for-offloaded-IPv6.patch"

[ -s "$patch_971" ] || {
	echo "missing required IPv6 UPDMEM patch 971" >&2
	exit 1
}

if find target/linux -type f -name '*965*ipv6*vlan*' | grep -q .; then
	echo "forbidden selective fallback patch 965 is present" >&2
	exit 1
fi

[ -s package/kernel/mt76/patches/020-wifi-mt76-mt7996-report-radar-on-detecting-chanctx.patch ] || {
	echo "missing mt7996 radar chanctx patch" >&2
	exit 1
}

grep -Fq 'rtl8261ce_match_phy_device' \
	target/linux/generic/files/drivers/net/phy/rtl8261ce/rtk_rtl8261ce_phy.c || {
	echo "strict RTL8261CE matcher is missing" >&2
	exit 1
}

grep -Fq 'ramoops@86ff0000' target/linux/airoha/dts/an7581.dtsi || {
	echo "64 KiB ramoops reservation is missing" >&2
	exit 1
}
