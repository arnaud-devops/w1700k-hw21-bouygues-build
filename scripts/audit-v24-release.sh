#!/usr/bin/env bash

set -euo pipefail

EXPECTED_SOURCE="2d02d62666bd8f6ef89b193238c58984db592330"
EXPECTED_UPSTREAM="97d6719ca75cf7e9ecd1d40e7b95f47531e8074f"
EXPECTED_BRIDGE_PR="74d7154fd7bfed8d4d04d48ec23db51937c12756"
EXPECTED_KERNEL="6.18.39"
EXPECTED_HOSTAPD="f08f2749aa696c4e47c5c0f591dda99951bf9fac"
EXPECTED_MT76="59676919ea408b0b13a9d23f2e2e1a1ab407fba1"
EXPECTED_PACKAGES_FEED="81d81033e6a278663c6e0414f0ec07d37b1141bd"
EXPECTED_LUCI_FEED="96a255dbd96212b1c42cfbd0969425ab6528c8b2"
EXPECTED_ROUTING_FEED="c7872431105f69894201dc522b7560e47d1e8ba9"
EXPECTED_BUILDER_IMAGE="ghcr.io/arnaud-devops/w1700k-hw21-bouygues-builder@sha256:88dac182e7327e61d76aba0836d1c16924cee7fd0407b41e561d1fb514b3acd9"
EXPECTED_PATCH_972="c2a595edea73066bfc7c0077ed9c2195a412230f1c084b284ceb45a1ea8e2434"
EXPECTED_PATCH_973="10f0effbe1650cb271f282d5f6e3c1d63f9276022fd4a2dfc44bf7de9d4988c3"
EXPECTED_RTL_PATCH="09fa20688be4888b3177938b962a51c39c0eb7f27cbd9cd52abbcd6e76be60c2"
EXPECTED_POLICY_PATCH="0f7d4f42079a5a8d5692211494277c7aed52125bc13b32384bd6ecffd411e437"
EXPECTED_FW4_PATCH="712848a7a5a348bd87b4f4b153fe62c97a3cb01c77b9ed0de0df2cf2e3c2e8b7"
EXPECTED_RECOVERY="ef7968b48909c838aadb8de388ded577e1ba04b7eae107cc053ff2018e1ac5fd"
EXPECTED_MT76_SOE_COMPANION="11438ddb5aef99f3e9ef359c5c96d1ce04ac46c2b273d12baec3b3b0a0d9c615"
REPOSITORY="arnaud-devops/w1700k-hw21-bouygues-build"

usage() {
	printf 'Usage: %s RELEASE_DIRECTORY\n' "$0" >&2
	exit 2
}

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

pass() {
	printf 'PASS: %s\n' "$*"
}

require_command() {
	command -v "$1" >/dev/null 2>&1 || fail "missing command: $1"
}

file_size() {
	if stat -f %z "$1" >/dev/null 2>&1; then
		stat -f %z "$1"
	else
		stat -c %s "$1"
	fi
}

[ "$#" -eq 1 ] || usage
release_dir="${1%/}"
[ -d "$release_dir" ] || fail "release directory not found: $release_dir"

for command_name in awk cmp dtc dumpimage fdtget find gh grep jq sed \
	sha256sum stat strings unsquashfs; do
	require_command "$command_name"
done

if find "$release_dir" -type f \( -path '*/raw/*' -o -name '*.tar.gz' \) |
	grep -q .; then
	fail "raw or tar.gz material is present in the release directory"
fi

shopt -s nullglob
images=("$release_dir"/*sysupgrade.itb)
manifests=("$release_dir"/*.manifest)
boms=("$release_dir"/*.bom.cdx.json)
apks=("$release_dir"/*.apk)
kmod_apks=("$release_dir"/kmod-*.apk)
shopt -u nullglob

[ "${#images[@]}" -eq 1 ] || fail "expected one sysupgrade ITB, found ${#images[@]}"
[ "${#manifests[@]}" -eq 1 ] || fail "expected one manifest, found ${#manifests[@]}"
[ "${#boms[@]}" -eq 1 ] || fail "expected one SBOM, found ${#boms[@]}"
[ "${#kmod_apks[@]}" -ge 100 ] ||
	fail "native kmod repository is unexpectedly small: ${#kmod_apks[@]}"

image="${images[0]}"
manifest="${manifests[0]}"
bom="${boms[0]}"
profiles="$release_dir/profiles.json"
checksums="$release_dir/sha256sums"
build_info="$release_dir/build-info.txt"
config_diff="$release_dir/config.diff"
release_tag_file="$release_dir/release-tag.txt"
release_checksums="$release_dir/release-sha256sums"
repo_index="$release_dir/w1700k-kmods-index.json"
repo_adb="$release_dir/w1700k-kmods.adb"
repo_checksums="$release_dir/w1700k-kmods.sha256"
repo_info="$release_dir/w1700k-kmods-info.txt"
repo_key="$release_dir/w1700k-apk-public-key.pem"

for required_file in "$profiles" "$checksums" "$build_info" "$config_diff" \
	"$release_tag_file" "$release_checksums" "$repo_index" "$repo_adb" \
	"$repo_checksums" "$repo_info" "$repo_key"; do
	[ -s "$required_file" ] || fail "missing release asset: ${required_file##*/}"
done

tmp="$(mktemp -d "${TMPDIR:-/tmp}/w1700k-v24-audit.XXXXXX")"
cleanup() {
	rm -rf "$tmp"
}
trap cleanup EXIT HUP INT TERM

# GitHub release assets are downloaded into one directory. Normalize the
# original firmware/ and repository/ paths before checking the release lock.
sed -e 's#  firmware/#  #' -e 's#  repository/#  #' \
	"$release_checksums" > "$tmp/release-sha256sums.flat"
(cd "$release_dir" &&
	sha256sum --check --quiet "$tmp/release-sha256sums.flat") ||
	fail "top-level release checksum verification failed"
(cd "$release_dir" &&
	sha256sum --check --quiet "${repo_checksums##*/}") ||
	fail "native repository checksum verification failed"
(cd "$release_dir" &&
	sha256sum --check --ignore-missing --quiet "${checksums##*/}") ||
	fail "OpenWrt checksum verification failed"
pass "release, repository and OpenWrt checksums"

release_tag="$(tr -d '\r\n' < "$release_tag_file")"
[[ "$release_tag" =~ ^ubi2-hw21-bouygues_2026\.[0-9]{2}\.[0-9]{2}_r35578-2d02d62666_[0-9a-f]{7}$ ]] ||
	fail "unexpected release tag: $release_tag"
builder_commit="$(sed -n 's/^Builder commit: //p' "$build_info")"
[[ "$builder_commit" =~ ^[0-9a-f]{40}$ ]] ||
	fail "invalid builder commit in provenance"
[ "${builder_commit:0:7}" = "${release_tag##*_}" ] ||
	fail "release tag and builder commit differ"
tag_target="$(gh api "repos/$REPOSITORY/git/ref/tags/$release_tag" --jq .object.sha)"
[ "$tag_target" = "$builder_commit" ] ||
	fail "release tag does not target the recorded builder commit"
pass "release tag and builder commit"

image_name="${image##*/}"
actual_sha="$(sha256sum "$image" | awk '{print $1}')"
profile_sha="$(jq -er --arg name "$image_name" \
	'[.profiles[]?.images[]? | select(.name == $name) | .sha256] |
	 if length == 1 then .[0] else error("image count") end' "$profiles")"
profile_size="$(jq -er --arg name "$image_name" \
	'[.profiles[]?.images[]? | select(.name == $name) | .size] |
	 if length == 1 then .[0] else error("image count") end' "$profiles")"
[ "$actual_sha" = "$profile_sha" ] || fail "profiles.json checksum mismatch"
[ "$(file_size "$image")" = "$profile_size" ] ||
	fail "profiles.json image size mismatch"
jq -e --arg source "$EXPECTED_SOURCE" --arg kernel "$EXPECTED_KERNEL" '
	.target == "airoha/an7581" and
	.git_commit == $source and
	.linux_kernel.version == $kernel and
	([.profiles[]?.supported_devices[]?] |
	 index("gemtek,w1700k-ubi") != null)
' "$profiles" >/dev/null || fail "target, source, kernel or board mismatch"
pass "image size and OpenWrt profile provenance"

for asset in "$image" "$manifest" "$bom" "$profiles" "$build_info" \
	"$config_diff" "$repo_adb" "$repo_checksums" "$repo_info" "$repo_key" \
	"$release_checksums"; do
	gh attestation verify "$asset" --repo "$REPOSITORY" >/dev/null ||
		fail "GitHub attestation failed: ${asset##*/}"
done
pass "GitHub build-provenance attestations"

fit_listing="$tmp/fit-listing.txt"
dumpimage -l "$image" > "$fit_listing"
grep -Fq "ARM64 OpenWrt Linux-$EXPECTED_KERNEL" "$fit_listing" ||
	fail "FIT kernel mismatch"
grep -Fq 'ARM64 OpenWrt gemtek_w1700k-ubi2 device tree blob' "$fit_listing" ||
	fail "FIT DTB mismatch"
grep -Fq 'ARM64 OpenWrt gemtek_w1700k-ubi2 rootfs' "$fit_listing" ||
	fail "FIT rootfs mismatch"

metadata="$(strings "$image" | grep -m1 '"metadata_version"' || true)"
[ -n "$metadata" ] || fail "sysupgrade metadata not found"
printf '%s\n' "$metadata" | jq -e '
	.compat_version == "2.0" and
	(.new_supported_devices | index("gemtek,w1700k-ubi") != null) and
	.version.target == "airoha/an7581" and
	.version.board == "gemtek_w1700k-ubi2"
' >/dev/null || fail "sysupgrade metadata mismatch"

dtb="$tmp/w1700k.dtb"
rootfs_image="$tmp/rootfs.squashfs"
root="$tmp/root"
dumpimage -T flat_dt -p 1 -o "$dtb" "$image" >/dev/null
dumpimage -T flat_dt -p 2 -o "$rootfs_image" "$image" >/dev/null
mkdir "$root"
unsquashfs -processors 1 -force -no-exit-code -d "$root" \
	"$rootfs_image" >/dev/null
fdtget -l "$dtb" /reserved-memory | grep -qx 'ramoops@86ff0000' ||
	fail "ramoops node absent"
[ "$(fdtget -tx "$dtb" /reserved-memory/ramoops@86ff0000 reg)" = \
	'0 86ff0000 0 10000' ] || fail "ramoops reservation mismatch"
dtc -I dtb -O dts -o "$tmp/w1700k.dts" "$dtb" 2>/dev/null
if grep -Eq 'opp-hz = <0x00? (0x4a817c80|0x4d7c6d00|0x50775b80|0x53724a00|0x536e7e00)>' \
	"$tmp/w1700k.dts"; then
	fail "DTB contains an overclock OPP"
fi
pass "FIT, metadata, DTB, stock CPU ceiling and ramoops"

required_packages=(
	airoha-en7581-mt7996-npu-firmware apk-openssl curl dnsmasq-full
	dnsproxy dropbear ethtool-full firewall4 hostapd-common iperf3 irqbalance
	kmod-airoha-eth kmod-airoha-npu kmod-ifb kmod-mt7996e
	kmod-nf-flow-bridge kmod-nft-offload kmod-phy-rtl8261ce
	kmod-sched-cake librespeed-go luci-app-airoha-flowsense
	luci-app-airoha-npu luci-app-filemanager luci-app-irqbalance
	luci-app-log-viewer luci-app-mlo luci-app-netspeedtest
	luci-app-package-manager luci-app-sqm luci-app-ttyd luci-app-watchcat
	luci-app-w1700k-fancontrol luci-app-wifi7 openssh-sftp-server
	rtl826x-firmware sqm-scripts tcpdump ttyd watchcat
	w1700k-hw21-bouygues-support wpad-openssl
)
for package_name in "${required_packages[@]}"; do
	grep -q "^$package_name - " "$manifest" ||
		fail "required image package absent: $package_name"
done
for package_name in attendedsysupgrade-common bridge-flow-offload bridger \
	dnsmasq kmod-br-netfilter luci-app-attendedsysupgrade owut speedtest \
	wpad-basic-mbedtls wpad-mbedtls; do
	! grep -q "^$package_name - " "$manifest" ||
		fail "forbidden image package present: $package_name"
done
grep -q '^hostapd-common - 2026\.07\.09~f08f2749-r2$' "$manifest" ||
	fail "hostapd version mismatch"
grep -q '^wpad-openssl - 2026\.07\.09~f08f2749-r2$' "$manifest" ||
	fail "wpad version mismatch"
grep -q '^kmod-mt7996e - 6\.18\.39\.2026\.07\.01~59676919-r1$' "$manifest" ||
	fail "mt7996 version mismatch"
grep -q '^kmod-phy-rtl8261ce - 6\.18\.39-r1$' "$manifest" ||
	fail "RTL8261CE package version mismatch"
grep -q '^w1700k-hw21-bouygues-support - 2\.4\.0-r1$' "$manifest" ||
	fail "custom support package version mismatch"
pass "image package policy"

grep -qx 'CONFIG_ALL_KMODS=y' "$config_diff" ||
	fail "CONFIG_ALL_KMODS is absent"
grep -qx 'CONFIG_SIGNED_PACKAGES=y' "$config_diff" ||
	fail "signed package policy is absent"
grep -qx 'CONFIG_PACKAGE_u-boot-an7581_gemtek_w1700k=y' "$config_diff" ||
	fail "W1700K U-Boot selection is absent"
for disabled in CONFIG_PACKAGE_kmod-ipt-rtpengine \
	CONFIG_PACKAGE_kmod-br-netfilter CONFIG_PACKAGE_bridge-flow-offload \
	CONFIG_PACKAGE_owut CONFIG_PACKAGE_luci-app-attendedsysupgrade; do
	! grep -Eq "^${disabled}=[ym]$" "$config_diff" ||
		fail "forbidden config enabled: $disabled"
done
pass "native ALL_KMODS and build configuration policy"

jq -e '
	.bomFormat == "CycloneDX" and
	([.components[].name] | index("wpad-openssl") != null) and
	([.components[].name] | index("dnsproxy") != null) and
	([.components[].name] | index("w1700k-hw21-bouygues-support") != null) and
	([.components[].name] | index("wpad-basic-mbedtls") == null) and
	([.components[].name] | index("bridger") == null) and
	([.components[].name] | index("owut") == null)
' "$bom" >/dev/null || fail "CycloneDX SBOM policy mismatch"
pass "CycloneDX SBOM"

cmp -s "$build_info" "$root/build_info" ||
	fail "published and embedded provenance differ"
for expected_line in \
	"Builder container: $EXPECTED_BUILDER_IMAGE" \
	"OpenWrt/Hurryman commit: $EXPECTED_SOURCE" \
	"OpenWrt base commit: $EXPECTED_UPSTREAM" \
	"Bridge PR head inspected: $EXPECTED_BRIDGE_PR" \
	"Hostapd commit: $EXPECTED_HOSTAPD" \
	"mt76 commit: $EXPECTED_MT76" \
	"packages $EXPECTED_PACKAGES_FEED" \
	"luci $EXPECTED_LUCI_FEED" \
	"routing $EXPECTED_ROUTING_FEED" \
	"$EXPECTED_POLICY_PATCH  ./patches/0001-v24-remove-buildbot-vermagic-and-risky-defaults.patch" \
	"$EXPECTED_RTL_PATCH  ./patches/0002-rtl8261ce-require-ce-pma-model-at-bind-time.patch" \
	"$EXPECTED_FW4_PATCH  ./package/network/config/firewall4/patches/001-add-bridge-flowtable-support.patch" \
	"$EXPECTED_PATCH_972  ./target/linux/airoha/patches-6.18/972-net-airoha-sync-UPDMEM-source-MAC-for-offloaded-IPv6.patch" \
	"$EXPECTED_PATCH_973  ./target/linux/airoha/patches-6.18/973-net-airoha-UPDMEM-slot-allocator-for-IPv6-source-MACs.patch" \
	"$EXPECTED_RECOVERY  ./package/w1700k-hw21-bouygues-support/files/usr/local/sbin/restore-dnsproxy-after-sysupgrade"; do
	grep -Fq "$expected_line" "$build_info" ||
		fail "provenance line absent: $expected_line"
done
grep -Fq \
	"$EXPECTED_MT76_SOE_COMPANION  package/kernel/mt76/patches/9993-wifi-mt76-distinguish-flowtable-callbacks.patch" \
	"$build_info" || fail "excluded mt76 SOE companion provenance absent"
for forbidden_text in \
	'971-net-airoha-sync-UPDMEM-source-MAC-for-offloaded-IPv6.patch' \
	'965-net-airoha-disable-hw-offload-for-ipv6-vlan-uplink-only.patch' \
	'../../../files/etc/vermagic.txt'; do
	! grep -Fq "$forbidden_text" "$build_info" ||
		fail "forbidden provenance text present: $forbidden_text"
done
pass "source, feed and patch provenance"

for rel in \
	etc/apk/repositories.d/customfeeds.list \
	etc/config/ttyd \
	etc/hotplug.d/iface/95-dnsproxy-restore \
	etc/hotplug.d/net/50-flow-offload-wifi \
	etc/init.d/dnsproxy-restore \
	etc/init.d/irqbalance \
	etc/init.d/npu-jitter \
	etc/init.d/ttyd \
	etc/init.d/watchcat \
	etc/init.d/w1700k-pstore \
	etc/uci-defaults/99-w1700k-hw21-bouygues-v24 \
	etc/w1700k-build-release \
	usr/bin/curl usr/bin/flock usr/bin/iperf3 usr/bin/jq \
	usr/bin/librespeed-go usr/bin/tcpdump usr/bin/ttyd \
	usr/libexec/sftp-server usr/libexec/tc-full \
	usr/local/sbin/restore-dnsproxy-after-sysupgrade \
	usr/local/sbin/w1700k-healthcheck \
	usr/local/sbin/w1700k-pstore-collect \
	usr/local/sbin/w1700k-watchcat-recover \
	usr/sbin/ethtool usr/sbin/irqbalance usr/sbin/nft usr/sbin/wpad; do
	[ -e "$root/$rel" ] || fail "required rootfs path absent: $rel"
done
for rel in \
	etc/hotplug.d/iface/51-bridge-flow-offload \
	etc/hotplug.d/net/50-nf-bridge-call \
	etc/vermagic.txt usr/bin/fastfetch usr/bin/owut usr/bin/speedtest \
	usr/share/bridge-flow-offload \
	usr/share/luci/menu.d/luci-app-attendedsysupgrade.json \
	www/cgi-bin/github_check www/cgi-bin/github_fetch \
	www/luci-static/resources/view/netspeedtest/speedtest.js; do
	[ ! -e "$root/$rel" ] || fail "forbidden rootfs path present: $rel"
done

for firmware in \
	lib/firmware/airoha/en7581_MT7996_npu_data.bin \
	lib/firmware/airoha/en7581_MT7996_npu_rv32.bin \
	lib/firmware/mediatek/mt7996/mt7996_dsp.bin \
	lib/firmware/mediatek/mt7996/mt7996_rom_patch.bin \
	lib/firmware/mediatek/mt7996/mt7996_wa.bin \
	lib/firmware/mediatek/mt7996/mt7996_wm.bin \
	lib/firmware/rtl8261n.bin; do
	[ -s "$root/$firmware" ] || fail "required firmware absent: $firmware"
done
for module in airoha-eth.ko airoha_npu.ko mt7996e.ko \
	nf_flow_table_bridge.ko rtk-rtl8261ce-phy.ko; do
	[ "$(find "$root/lib/modules" -type f -name "$module" | wc -l |
		tr -d ' ')" -eq 1 ] || fail "required module absent or duplicated: $module"
done
pass "rootfs executables, firmware and kernel modules"

fw4="$root/usr/share/firewall4/templates/ruleset.uc"
defaults="$root/etc/uci-defaults/99-w1700k-hw21-bouygues-v24"
recovery="$root/usr/local/sbin/restore-dnsproxy-after-sysupgrade"
grep -Fq 'meta l4proto { tcp, udp } flow offload @ft;' "$fw4" ||
	fail "normal dual-stack flow rule absent"
grep -Fq 'flow_offloading_bridge' "$fw4" ||
	fail "fw4 bridge gate absent"
grep -Fq "flow_offloading_bridge='0'" "$defaults" ||
	fail "bridge offload is not disabled by default"
grep -Fq "flow_offloading_hw='1'" "$defaults" ||
	fail "routed hardware flow offload is not enabled"
grep -Fq "packet_steering='0'" "$defaults" ||
	fail "packet steering baseline is not disabled"
grep -Fq "irqbalance.\$section.enabled='1'" "$defaults" ||
	fail "irqbalance first-boot policy absent"
grep -Fq "set watchcat.wan_ipv6.mode='run_script'" "$defaults" ||
	fail "Watchcat IPv6 recovery policy absent"
grep -Fq "add_list dnsproxy.servers.upstream='quic://unfiltered.adguard-dns.com'" \
	"$recovery" || fail "AdGuard DoQ policy absent"
grep -Fq "add_list dnsproxy.servers.fallback='quic://dns.nextdns.io'" \
	"$recovery" || fail "NextDNS fallback policy absent"
grep -Fq "add_list dnsproxy.servers.bootstrap='185.222.222.222'" \
	"$recovery" || fail "DNS.SB bootstrap policy absent"
grep -Fq 'flock -n 9' "$recovery" ||
	fail "recovery serialization absent"
grep -Fq 'w1700k-v24.pem' "$defaults" ||
	fail "persistent repository key policy absent"
grep -Eq "^[[:space:]]*option enabled '0'$" \
	"$root/etc/config/npu-monitor" || fail "FlowSense jitter is not opt-in"
grep -Eq "^[[:space:]]*option enabled '0'$" \
	"$root/etc/config/librespeed-go" || fail "LibreSpeed is enabled by default"
grep -Eq "^[[:space:]]*option interface '@lan'$" \
	"$root/etc/config/ttyd" || fail "ttyd is not LAN-only"
grep -Eq "^[[:space:]]*option ssl '1'$" "$root/etc/config/ttyd" ||
	fail "ttyd TLS is disabled"
pass "PPE, bridge gate, DoQ, recovery and service defaults"

expected_repo="https://github.com/$REPOSITORY/releases/download/$release_tag/w1700k-kmods.adb"
[ "$(grep -Fxc "$expected_repo" \
	"$root/etc/apk/repositories.d/customfeeds.list")" -eq 1 ] ||
	fail "exact native APK repository URL absent"
if grep -Eq 'downloads\.openwrt\.org/.*/kmods/' \
	"$root"/etc/apk/repositories.d/*.list; then
	fail "incompatible official kmods feed remains"
fi
cmp -s "$repo_key" "$root/etc/apk/keys/public-key.pem" ||
	fail "published and embedded APK keys differ"
grep -Fqx "release_tag=$release_tag" "$root/etc/w1700k-build-release" ||
	fail "embedded release tag mismatch"
grep -Fqx "builder_commit=$builder_commit" "$root/etc/w1700k-build-release" ||
	fail "embedded builder commit mismatch"
grep -Fqx "source_commit=$EXPECTED_SOURCE" "$root/etc/w1700k-build-release" ||
	fail "embedded source commit mismatch"

repo_kernel="$(sed -n 's/^kernel=//p' "$repo_info")"
repo_vermagic="$(sed -n 's/^native_vermagic=//p' "$repo_info")"
repo_kmod_count="$(sed -n 's/^kmod_apk_count=//p' "$repo_info")"
repo_apk_count="$(sed -n 's/^total_apk_count=//p' "$repo_info")"
[ "$repo_kernel" = "$EXPECTED_KERNEL" ] || fail "repository kernel mismatch"
[[ "$repo_vermagic" =~ ^[0-9a-f]{32}$ ]] ||
	fail "invalid native vermagic"
[ "$repo_kmod_count" -eq "${#kmod_apks[@]}" ] ||
	fail "repository kmod count mismatch"
[ "$repo_apk_count" -eq "${#apks[@]}" ] ||
	fail "repository APK count mismatch"
for package_name in kernel kmod-airoha-eth kmod-airoha-npu \
	kmod-mt7996e kmod-nf-flow-bridge kmod-phy-rtl8261ce dnsproxy \
	wpad-openssl; do
	jq -e --arg package "$package_name" \
		'.. | objects | select(.name? == $package)' "$repo_index" >/dev/null ||
		fail "package absent from repository index: $package_name"
done
pass "signed native repository contents, key and vermagic metadata"

printf '\nAUDIT PASSED\n'
printf 'Release: %s\n' "$release_tag"
printf 'Image: %s\n' "$image_name"
printf 'Size: %s bytes\n' "$(file_size "$image")"
printf 'SHA-256: %s\n' "$actual_sha"
printf 'Kernel: %s\n' "$EXPECTED_KERNEL"
printf 'Native vermagic: %s\n' "$repo_vermagic"
printf 'Kmod APKs: %s\n' "$repo_kmod_count"
