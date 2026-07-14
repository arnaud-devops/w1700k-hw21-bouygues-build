#!/bin/bash

set -euo pipefail

# This profile has no generic online-upgrade client. Do not expose the inherited
# CGI helpers that download unrelated w1700k/builds images into /tmp.
rm -f \
	files/overview.js \
	files/www/cgi-bin/github_check \
	files/www/cgi-bin/github_fetch

# Retain the single-wiphy/multi-radio LuCI channel-analysis correction.
mkdir -p feeds/luci/modules/luci-mod-status/patches
mv files/998-single-wiphy.patch \
	feeds/luci/modules/luci-mod-status/patches/998-single-wiphy.patch
