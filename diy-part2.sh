#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#

# Modify default IP
# 创建首次开机自动配置脚本（关闭 LAN 口 IPv6 通告）
mkdir -p files/etc/uci-defaults
cat << 'EOF' > files/etc/uci-defaults/99-disable-lan-ipv6
#!/bin/sh
uci set dhcp.lan.ra='disabled'
uci set dhcp.lan.dhcpv6='disabled'
uci commit dhcp
exit 0
EOF
#######
chmod +x files/etc/uci-defaults/99-disable-lan-ipv6
sed -i 's/192.168.1.1/10.103.1.2/g' package/base-files/files/bin/config_generate
#sed -i '/^VERSION_NUMBER:=$(if/ s/24\.10-SNAPSHOT/24.10-lenyu/' include/version.mk #24.10
#sed -i 's/KERNEL_PATCHVER:=5.15/KERNEL_PATCHVER:=5.10/g' target/linux/x86/Makefile
#sed -i "s/.*PKG_VERSION:=.*/PKG_VERSION:=4.3.9_v1.2.14/" package/lean/qBittorrent-static/Makefile
#sed -i 's/download-ci-llvm = true/download-ci-llvm = false/g' feeds/packages/lang/rust/Makefile
# welcome test

# xray-core 要求 go >= 1.27；openwrt-25.12 的 packages feed 仍是 1.26.8 且 GOTOOLCHAIN=local。
# 必须在 feeds update 之后替换（写在 diy-part1.sh 会被 packages feed 覆盖）。
rm -rf feeds/packages/lang/golang
git clone --depth 1 --filter=blob:none --sparse \
  https://github.com/immortalwrt/packages.git /tmp/iw-packages-golang
git -C /tmp/iw-packages-golang sparse-checkout set lang/golang
cp -a /tmp/iw-packages-golang/lang/golang feeds/packages/lang/golang
rm -rf /tmp/iw-packages-golang
# 拷贝后必须刷新 feed 索引，否则仍按 1.26 注册，world 会报 golang1.27/host 不存在
./scripts/feeds update -i packages
rm -rf package/feeds/packages/golang1.26
./scripts/feeds install golang golang1.27
./scripts/feeds install -a -p packages
ls -d package/feeds/packages/golang* feeds/packages/lang/golang/golang*
find feeds/packages/lang/golang -name 'golang-package.mk' -exec \
  sed -i 's/GOTOOLCHAIN=local/GOTOOLCHAIN=auto/g' {} +
find feeds/packages/lang/golang -name 'golang-package.mk' -exec \
  sed -i 's|GOPROXY=off|GOPROXY=https://proxy.golang.org,direct|g' {} +
grep -n 'GO_DEFAULT_VERSION' feeds/packages/lang/golang/golang-values.mk
grep -n 'GOTOOLCHAIN' feeds/packages/lang/golang/golang-package.mk

# 保留 mosdns：只修 feeds 自带 5.3.3（缺 /v5、quic-go 过旧），不删除包
MOSDNS_MK="feeds/packages/net/mosdns/Makefile"
if [ -f "$MOSDNS_MK" ]; then
  sed -i 's/^PKG_VERSION:=5.3.3/PKG_VERSION:=5.3.4/' "$MOSDNS_MK"
  sed -i 's/^PKG_HASH:=1d7eeaa735cb48ed2d436797d7f2a82541699f74647cd293ee411a72cdc65f5f/PKG_HASH:=0302a685db2a6c3c09af7bf4ff0dffd24f1e583383a47f064564f5270033671b/' "$MOSDNS_MK"
  sed -i 's|^GO_PKG:=github.com/IrineSistiana/mosdns$|GO_PKG:=github.com/IrineSistiana/mosdns/v5|' "$MOSDNS_MK"
  grep -E 'PKG_VERSION|PKG_HASH|^GO_PKG:=' "$MOSDNS_MK"
fi
