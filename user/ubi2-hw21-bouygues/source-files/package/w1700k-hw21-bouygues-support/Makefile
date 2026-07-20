include $(TOPDIR)/rules.mk

PKG_NAME:=w1700k-hw21-bouygues-support
PKG_VERSION:=2.1.0
PKG_RELEASE:=1
PKGARCH:=all
PKG_LICENSE:=GPL-2.0-only
PKG_MAINTAINER:=Arnaud <arnaud-devops@users.noreply.github.com>

include $(INCLUDE_DIR)/package.mk

define Package/w1700k-hw21-bouygues-support
  SECTION:=net
  CATEGORY:=Network
  TITLE:=W1700K HW2.1 Bouygues recovery and diagnostics
  DEPENDS:=+dnsmasq-full +dnsproxy +irqbalance +jsonfilter +watchcat +wpad-openssl
endef

define Package/w1700k-hw21-bouygues-support/description
 Recovery, health-check and pstore helpers for the pinned W1700K HW2.1
 Bouygues image. No device credentials or ISP identifiers are embedded.
endef

define Build/Compile
endef

define Package/w1700k-hw21-bouygues-support/install
	$(INSTALL_DIR) $(1)/etc/hotplug.d/iface
	$(INSTALL_BIN) ./files/etc/hotplug.d/iface/95-dnsproxy-restore \
		$(1)/etc/hotplug.d/iface/95-dnsproxy-restore
	$(INSTALL_DIR) $(1)/etc/hotplug.d/net
	$(INSTALL_BIN) ./files/etc/hotplug.d/net/50-flow-offload-wifi \
		$(1)/etc/hotplug.d/net/50-flow-offload-wifi
	$(INSTALL_BIN) ./files/etc/hotplug.d/net/50-nf-bridge-call \
		$(1)/etc/hotplug.d/net/50-nf-bridge-call
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/dnsproxy-restore \
		$(1)/etc/init.d/dnsproxy-restore
	$(INSTALL_BIN) ./files/etc/init.d/w1700k-pstore \
		$(1)/etc/init.d/w1700k-pstore
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/etc/uci-defaults/99-w1700k-hw21-bouygues-v2 \
		$(1)/etc/uci-defaults/99-w1700k-hw21-bouygues-v2
	$(INSTALL_DIR) $(1)/usr/local/sbin
	$(INSTALL_BIN) ./files/usr/local/sbin/restore-dnsproxy-after-sysupgrade \
		$(1)/usr/local/sbin/restore-dnsproxy-after-sysupgrade
	$(INSTALL_BIN) ./files/usr/local/sbin/w1700k-healthcheck \
		$(1)/usr/local/sbin/w1700k-healthcheck
	$(INSTALL_BIN) ./files/usr/local/sbin/w1700k-pstore-collect \
		$(1)/usr/local/sbin/w1700k-pstore-collect
	$(INSTALL_BIN) ./files/usr/local/sbin/w1700k-watchcat-recover \
		$(1)/usr/local/sbin/w1700k-watchcat-recover
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./files/usr/sbin/tx-debug.sh $(1)/usr/sbin/tx-debug.sh
endef

$(eval $(call BuildPackage,w1700k-hw21-bouygues-support))
