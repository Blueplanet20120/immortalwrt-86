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
