#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
#

# Uncomment a feed source
# Add a feed helloword
sed -i "/helloworld/d" "feeds.conf.default"
sed -i "/nikki/d" "feeds.conf.default"
echo "src-git helloworld https://github.com/fw876/helloworld.git" >> "feeds.conf.default"
echo "src-git nikki https://github.com/nikkinikki-org/OpenWrt-nikki.git;main" >> "feeds.conf.default"
# 强行将最新的 PassWall 专属 feed 注入到 feeds.conf.default 的最顶部
sed -i '1i src-git passwall_luci https://github.com/Openwrt-Passwall/openwrt-passwall.git;main' feeds.conf.default
sed -i '1i src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main' feeds.conf.default

# Add a feed source

mkdir -p files/usr/share
mkdir -p files/etc/
touch files/etc/lenyu_version
mkdir wget
touch wget/DISTRIB_REVISION1
touch wget/DISTRIB_REVISION3
touch files/usr/share/Check_Update.sh
touch files/usr/share/Lenyu-auto.sh
touch files/usr/share/Lenyu-pw.sh

# 修改为源码内部的相对路径，彻底解决 Permission denied 报错
# touch package/base-files/files/etc/sysupgrade.conf

# 修改为源码内部的相对路径
cat>>package/base-files/files/etc/sysupgrade.conf<<-EOF
/etc/config/dhcp
/etc/config/sing-box
/etc/config/romupdate
/etc/config/passwall_show
/etc/config/passwall_server
/etc/config/passwall
#/etc/openclash/core/ #dev
/usr/share/passwall/rules/
/usr/share/singbox/
/usr/bin/chinadns-ng
/usr/bin/sing-box
/usr/bin/hysteria
EOF


cat>rename.sh<<-'EOF'
#!/bin/bash

TARGET_DIR="bin/targets/x86/64"

# 1. 兜底检查，确保脚本在 openwrt 根目录下执行
if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: 找不到 $TARGET_DIR，请确认当前路径。"
    exit 1
fi

# 确保存放 version 记录的目录存在
mkdir -p wget

# 2. 批量清理冗余文件
rm -f ${TARGET_DIR}/*.buildinfo
rm -f ${TARGET_DIR}/*.manifest
rm -f ${TARGET_DIR}/sha256sums
rm -f ${TARGET_DIR}/profiles.json
rm -f ${TARGET_DIR}/*-kernel.bin
rm -f ${TARGET_DIR}/*-rootfs.*
rm -f ${TARGET_DIR}/*.vmdk
rm -f ${TARGET_DIR}/*ext4-combined-efi.img.gz
rm -f ${TARGET_DIR}/*ext4-combined.img.gz
# 3. 读取前面 lenyu.sh 注入的自定义版本号
if [ -f "files/etc/lenyu_version" ]; then
    rename_version=$(cat files/etc/lenyu_version)
else
    rename_version="unknown"
    echo "Warning: files/etc/lenyu_version 未找到，使用 fallback 版本号。"
fi

# 4. 动态解析内核大版本与补丁号 (基于 25.12+ 确切文件结构)
kernel_patchver=$(grep "KERNEL_PATCHVER:=" target/linux/x86/Makefile | cut -d '=' -f2 | tr -d ' ')
kernel_generic_file="target/linux/generic/kernel-${kernel_patchver}"

if [ -f "$kernel_generic_file" ]; then
    # 精准抓取 LINUX_VERSION-6.12 = .94 行，提取出其中的后半部分（带点的 .94）
    ver=$(grep "LINUX_VERSION-${kernel_patchver}" "$kernel_generic_file" | cut -d '=' -f2 | tr -d ' ')
else
    ver=""
fi

# 5. 组合【纯净版号】与【文件名 Base】
# 组合出来的 pure_version 格式形如：2607100810_sta_Len_yu_6.12.94
pure_version="${rename_version}_${kernel_patchver}${ver}"
base_name="immortalwrt_x86-64-${pure_version}"

dest_img_name="${base_name}_sta_Lenyu.img.gz"
dest_efi_name="${base_name}_uefi-gpt_sta_Lenyu.img.gz"

# 6. 切换到目标目录执行重命名与 MD5 生成
cd "$TARGET_DIR" || exit 1

# 处理 Legacy BIOS 传统固件
if [ -f "immortalwrt-x86-64-generic-squashfs-combined.img.gz" ]; then
    mv "immortalwrt-x86-64-generic-squashfs-combined.img.gz" "$dest_img_name"
    md5sum "$dest_img_name" > immortalwrt_sta.md5
else
    echo "Warning: 传统启动镜像文件不存在，已跳过。"
fi

# 处理 UEFI 固件
if [ -f "immortalwrt-x86-64-generic-squashfs-combined-efi.img.gz" ]; then
    mv "immortalwrt-x86-64-generic-squashfs-combined-efi.img.gz" "$dest_efi_name"
    md5sum "$dest_efi_name" > immortalwrt_sta_uefi.md5
else
    echo "Warning: UEFI 镜像文件不存在，已跳过。"
fi

# 7. 回到根目录，生成供 GitHub Actions Release 提取的标签与文件清单
cd - >/dev/null

# 【核心修改点】：这里只输出纯净的版本号给 GitHub，剥离多余的前后缀
echo "$pure_version" > wget/op_version1

ls -1 ${TARGET_DIR} > wget/open_sta_md5

exit 0
EOF

cat>lenyu.sh<<-'EOOF'
#!/bin/bash

# 1. 预先创建需要的目录，防止报错
mkdir -p wget files/etc

# 2. 生成版本号 (统一使用下划线代替不规范的空格，保证变量安全性)
lenyu_version="$(date '+%y%m%d%H%M')_sta_Len_yu" 
echo "$lenyu_version" > wget/DISTRIB_REVISION1 
echo "$lenyu_version" | cut -d _ -f 1 > files/etc/lenyu_version  
new_DISTRIB_REVISION=$(cat wget/DISTRIB_REVISION1)
# 3.替换 os-release 模板（适配ImmortalWrt 25.12 去除末尾的 %C 以移除 Git commit 号）
os_release_template="package/base-files/files/usr/lib/os-release"
[ -f "$os_release_template" ] && sed -i "s|OPENWRT_RELEASE=\"%D %V %C\"|OPENWRT_RELEASE=\"ImmortalWrt 25.12-${new_DISTRIB_REVISION}\"|g" "$os_release_template"

# 定义需要修改的默认设置文件路径
TARGET_FILE="package/emortal/default-settings/files/99-default-settings"

# 容错处理：确保目标文件存在
if [ ! -f "$TARGET_FILE" ]; then
    echo "Error: $TARGET_FILE not found!"
    exit 1
fi

# 3. 注入 Check_Update.sh 别名和系统版本描述
if ! grep -q "Check_Update.sh" "$TARGET_FILE"; then
    # 彻底清除文件末尾的 exit 0，防止逻辑中断
    sed -i 's/exit 0//g' "$TARGET_FILE"
    # 注意：此处 EOF 前不要加斜杠，以允许 $new_DISTRIB_REVISION 变量展开；
    # 内部包含 $ 的普通命令则使用 \$ 转义。
    cat >> "$TARGET_FILE" <<-EOF
	sed -i '\$ a alias lenyu="sh /usr/share/Check_Update.sh"' /etc/profile
	sed -i '/DISTRIB_DESCRIPTION/d' /etc/openwrt_release
	echo "DISTRIB_DESCRIPTION='$new_DISTRIB_REVISION'" >> /etc/openwrt_release
	exit 0
	EOF
fi

# 4. 注入 Lenyu-auto.sh 别名
if ! grep -q "Lenyu-auto.sh" "$TARGET_FILE"; then
    sed -i 's/exit 0//g' "$TARGET_FILE"
    cat >> "$TARGET_FILE" <<-\EOF
	sed -i '$ a alias lenyu-auto="sh /usr/share/Lenyu-auto.sh"' /etc/profile
	exit 0
	EOF
fi

# 5. 注入 Lenyu-pw.sh 别名
if ! grep -q "Lenyu-pw.sh" "$TARGET_FILE"; then
    sed -i 's/exit 0//g' "$TARGET_FILE"
    cat >> "$TARGET_FILE" <<-\EOF
	sed -i '$ a alias lenyu-pw="sh /usr/share/Lenyu-pw.sh"' /etc/profile
	exit 0
	EOF
fi

# 6. 注入 backup.tar.gz 定时恢复逻辑 (rc.local)
if ! grep -q "custom-backup.tar.gz" "$TARGET_FILE"; then
    sed -i 's/exit 0//g' "$TARGET_FILE"
    cat >> "$TARGET_FILE" <<-\EOF
	###### 添加定时执行 rc.local 任务
	# 检查 /etc/crontabs/root 中 rc.local 的出现次数，忽略找不到文件时的报错
	RC_COUNT=$(grep -c "rc.local" /etc/crontabs/root 2>/dev/null || echo 0)
	
	# 删除多余的 rc.local 条目
	if [ "$RC_COUNT" -gt 1 ]; then
	    awk '/rc.local/ && !seen {print; seen=1; next} !/rc.local/' /etc/crontabs/root > /tmp/crontabs_root_tmp && mv /tmp/crontabs_root_tmp /etc/crontabs/root
	    echo "Removed extra rc.local entries, kept one" >> /tmp/restore.log
	elif [ "$RC_COUNT" -eq 0 ]; then
	    # 如果没有 rc.local，添加一条
	    echo "@reboot sleep 60 && bash /etc/rc.local > /dev/null 2>&1 &" >> /etc/crontabs/root
	    echo "Add rc.local succeeded" >> /tmp/restore.log
	else
	    echo "rc.local already exists, no action taken" >> /tmp/restore.log
	fi
	
	##### 覆写 /etc/rc.local 文件内容
	cat > /etc/rc.local <<-\EOFF
	# Restoring the ROM configuration file
	get_smallest_mounted_disk() {
	    # 使用 lsblk 列出挂载在 /mnt/ 下的设备并过滤掉小于 100M 的设备
	    lsblk -o NAME,SIZE,MOUNTPOINT | grep "/mnt/" | awk '$2 ~ /[0-9.]+[G]/ || ($2 ~ /[0-9.]+M/ && $2+0 > 100) {print $1, $2}' > /tmp/tmdisk
	    # 计算最小的磁盘并将其路径存入 tmdisk 变量
	    tmdisk=/mnt/$(grep "" /tmp/tmdisk | awk '
	    $2 ~ /M/ {size = $2+0} 
	    $2 ~ /G/ {size = $2*1024} 
	    NR == 1 {min = size; line = $1} 
	    NR > 1 && size < min {min = size; line = $1} 
	    END {gsub(/[^a-zA-Z0-9]/, "", line); print line}')
	
	    # 输出结果
	    echo "$tmdisk"
	}
	
	# 调用函数并将结果存储到变量
	disk_path=$(get_smallest_mounted_disk)
	if [ -f "${disk_path}/custom-backup.tar.gz" ]; then
	    echo "Restore script already exists: ${disk_path}/custom-backup.tar.gz"
	    echo "Performing Restore..."
	    bash /usr/share/custom-restore.sh
	    echo "Restore completed."
	    echo "Restore successful $(date '+%Y-%m-%d %H:%M:%S')" >> /tmp/restore.log
	    
	    # Restart Passwall service
	    /etc/init.d/passwall restart
	    exit 0
	else
	    echo "Restore failed: file not found $(date '+%Y-%m-%d %H:%M:%S')" >> /tmp/restore.log
	    exit 1
	fi
	exit 0
	EOFF
	exit 0
	EOF
fi
EOOF

cat>files/usr/share/Check_Update.sh<<-'EOF'
#!/bin/bash
# https://github.com/Blueplanet20120/Actions-OpenWrt-x86
# Actions-OpenWrt-x86 By Lenyu 20210505
#path=$(dirname $(readlink -f $0))
# cd ${path}
#检测准备
if [ ! -f  "/etc/lenyu_version" ]; then
	echo
	echo -e "\033[31m 该脚本在非Lenyu固件上运行，为避免不必要的麻烦，准备退出… \033[0m"
	echo
	exit 0
fi
rm -f /tmp/cloud_version
# 获取固件云端版本号、内核版本号信息
current_version=`cat /etc/lenyu_version`
curl -s https://api.github.com/repos/Blueplanet20120/immortalwrt-86/releases/latest | grep 'tag_name' | cut -d\" -f4 > /tmp/cloud_ts_version
sleep 3
if [ -s  "/tmp/cloud_ts_version" ]; then
	cloud_version=`cat /tmp/cloud_ts_version | cut -d _ -f 1`
	cloud_kernel=`cat /tmp/cloud_ts_version | cut -d _ -f 2`
	#固件下载地址
	new_version=`cat /tmp/cloud_ts_version`
	DEV_URL=https://github.com/Blueplanet20120/immortalwrt-86/releases/download/${new_version}/immortalwrt_x86-64-${new_version}_sta_Lenyu.img.gz
	DEV_UEFI_URL=https://github.com/Blueplanet20120/immortalwrt-86/releases/download/${new_version}/immortalwrt_x86-64-${new_version}_uefi-gpt_sta_Lenyu.img.gz
	immortalwrt_sta=https://github.com/Blueplanet20120/immortalwrt-86/releases/download/${new_version}/immortalwrt_sta.md5
	immortalwrt_sta_uefi=https://github.com/Blueplanet20120immortalwrt-86/releases/download/${new_version}/immortalwrt_sta_uefi.md5
else
	echo "请检测网络或重试！"
	exit 1
fi
####
Firmware_Type="$(grep 'DISTRIB_ARCH=' /etc/immortalwrt_release | cut -d \' -f 2)"
echo $Firmware_Type > /etc/lenyu_firmware_type
echo
if [[ "$cloud_kernel" =~ "4.19" ]]; then
	echo
	echo -e "\033[31m 该脚本在Lenyu固件Sta版本上运行，目前只建议在Dev版本上运行，准备退出… \033[0m"
	echo
	exit 0
fi
#md5值验证，固件类型判断
if [ ! -d /sys/firmware/efi ];then
	if [ "$current_version" != "$cloud_version" ];then
		wget -P /tmp "$DEV_URL" -O /tmp/immortalwrt_x86-64-${new_version}_sta_Lenyu.img.gz
		wget -P /tmp "$immortalwrt_sta" -O /tmp/immortalwrt_sta.md5
		cd /tmp && md5sum -c immortalwrt_sta.md5
		if [ $? != 0 ]; then
      echo "您下载文件失败，请检查网络重试…"
      sleep 4
      exit
		fi
		Boot_type=logic
	else
		echo -e "\033[32m 本地已经是最新版本，还更个鸡巴毛啊… \033[0m"
		echo
		exit
	fi
else
	if [ "$current_version" != "$cloud_version" ];then
		wget -P /tmp "$DEV_UEFI_URL" -O /tmp/immortalwrt_x86-64-${new_version}_uefi-gpt_sta_Lenyu.img.gz
		wget -P /tmp "$immortalwrt_sta_uefi" -O /tmp/immortalwrt_sta_uefi.md5
		cd /tmp && md5sum -c immortalwrt_sta_uefi.md5
		if [ $? != 0 ]; then
      echo "您下载文件失败，请检查网络重试…"
      sleep 4
      exit
		fi
		Boot_type=efi
	else
		echo -e "\033[32m 本地已经是最新版本，还更个鸡巴毛啊… \033[0m"
		echo
		exit
	fi
fi

open_up()
{
echo
clear
read -n 1 -p  " 您是否要保留配置升级，保留选择Y,否则选N:" num1
echo
case $num1 in
	Y|y)
	echo
  echo -e "\033[32m >>>正在准备保留配置升级，请稍后，等待系统重启…-> \033[0m"
	echo
	sleep 3
	if [ ! -d /sys/firmware/efi ];then
		sysupgrade /tmp/immortalwrt_x86-64-${new_version}_sta_Lenyu.img.gz
	else
		sysupgrade /tmp/immortalwrt_x86-64-${new_version}_uefi-gpt_sta_Lenyu.img.gz
	fi
    ;;
    n|N)
    echo
    echo -e "\033[32m >>>正在准备不保留配置升级，请稍后，等待系统重启…-> \033[0m"
    echo
    sleep 3
	if [ ! -d /sys/firmware/efi ];then
		sysupgrade -n  /tmp/immortalwrt_x86-64-${new_version}_sta_Lenyu.img.gz
	else
		sysupgrade -n  /tmp/immortalwrt_x86-64-${new_version}_uefi-gpt_sta_Lenyu.img.gz
	fi
    ;;
    *)
	  echo
    echo -e "\033[31m err：只能选择Y/N\033[0m"
	  echo
    read -n 1 -p  "请回车继续…"
	  echo
	  open_up
esac
}

open_op()
{
echo
read -n 1 -p  " 您确定要升级吗，升级选择Y,否则选N:" num1
echo
case $num1 in
	Y|y)
	  open_up
    ;;
  n|N)
    echo
    echo -e "\033[31m >>>您已选择退出固件升级，已经终止脚本…-> \033[0m"
    echo
    exit 1
    ;;
  *)
    echo
    echo -e "\033[31m err：只能选择Y/N\033[0m"
    echo
    read -n 1 -p  "请回车继续…"
    echo
    open_op
esac
}
open_op
exit 0
EOF

cat>files/usr/share/Lenyu-auto.sh<<-'EOF'
#!/bin/bash
# https://github.com/Blueplanet20120/immortalwrt-86
# Actions-OpenWrt-x86 By Lenyu 20210505
#path=$(dirname $(readlink -f $0))
# cd ${path}
#检测准备
if [ ! -f  "/etc/lenyu_version" ]; then
echo
echo -e "\033[31m 该脚本在非Lenyu固件上运行，为避免不必要的麻烦，准备退出… \033[0m"
echo
exit 0
fi
rm -f /tmp/cloud_version

# 获取固件云端版本号、内核版本号信息
current_version=`cat /etc/lenyu_version`
# wget -qO- -T2 "https://api.github.com/repos/Blueplanet20120/immortalwrt-86/releases/latest" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g;s/v//g'  > /tmp/cloud_ts_version
# 因immortalwrt不支持上述格式.
curl -s https://api.github.com/repos/Blueplanet20120/immortalwrt-86/releases/latest | grep 'tag_name' | cut -d\" -f4 > /tmp/cloud_ts_version
sleep 3
if [ -s  "/tmp/cloud_ts_version" ]; then
cloud_version=`cat /tmp/cloud_ts_version | cut -d _ -f 1`
cloud_kernel=`cat /tmp/cloud_ts_version | cut -d _ -f 2`
#固件下载地址
new_version=`cat /tmp/cloud_ts_version` # 2208052057_5.4.203
DEV_URL=https://github.com/Blueplanet20120/immortalwrt-86/releases/download/${new_version}/immortalwrt_x86-64-${new_version}_sta_Lenyu.img.gz
DEV_UEFI_URL=https://github.com/Blueplanet20120/immortalwrt-86/releases/download/${new_version}/immortalwrt_x86-64-${new_version}_uefi-gpt_sta_Lenyu.img.gz
immortalwrt_sta=https://github.com/Blueplanet20120/immortalwrt-86/releases/download/${new_version}/immortalwrt_sta.md5
immortalwrt_sta_uefi=https://github.com/Blueplanet20120/immortalwrt-86/releases/download/${new_version}/immortalwrt_sta_uefi.md5
else
echo "请检测网络或重试！"
exit 1
fi
####
Firmware_Type="$(grep 'DISTRIB_ARCH=' /etc/lenyu_version | cut -d \' -f 2)"
echo $Firmware_Type > /etc/lenyu_firmware_type
echo
if [[ "$cloud_kernel" =~ "4.19" ]]; then
echo
echo -e "\033[31m 该脚本在Lenyu固件Sta版本上运行，目前只建议在Dev版本上运行，准备退出… \033[0m"
echo
exit 0
fi
#md5值验证，固件类型判断
if [ ! -d /sys/firmware/efi ];then
if [ "$current_version" != "$cloud_version" ];then
wget -P /tmp "$DEV_URL" -O /tmp/immortalwrt_x86-64-${new_version}_sta_Lenyu.img.gz
wget -P /tmp "$immortalwrt_sta" -O /tmp/immortalwrt_sta.md5
cd /tmp && md5sum -c immortalwrt_sta.md5
if [ $? != 0 ]; then
  echo "您下载文件失败，请检查网络重试…"
  sleep 4
  exit
fi
# Backing the ROM configuration file
bash /usr/share/custom-backup.sh
# update rom
sysupgrade /tmp/immortalwrt_x86-64-${new_version}_sta_Lenyu.img.gz
else
echo -e "\033[32m 本地已经是最新版本，还更个鸡巴毛啊… \033[0m"
echo
exit
fi
else
if [ "$current_version" != "$cloud_version" ];then
wget -P /tmp "$DEV_UEFI_URL" -O /tmp/immortalwrt_x86-64-${new_version}_uefi-gpt_sta_Lenyu.img.gz
wget -P /tmp "$immortalwrt_sta_uefi" -O /tmp/immortalwrt_sta_uefi.md5
cd /tmp && md5sum -c immortalwrt_sta_uefi.md5
if [ $? != 0 ]; then
echo "您下载文件失败，请检查网络重试…"
sleep 1
exit
fi
# Backing the ROM configuration file
bash /usr/share/custom-backup.sh
# update rom
sysupgrade /tmp/immortalwrt_x86-64-${new_version}_uefi-gpt_sta_Lenyu.img.gz
else
echo -e "\033[32m 本地已经是最新版本，还更个鸡巴毛啊… \033[0m"
echo
exit
fi
fi
exit 0
EOF

cat>files/usr/share/Lenyu-pw.sh<<'EOF_PW'
#!/bin/sh
# 在路由器上直接运行。
# 1. 自动判断发行版、架构、apk 或 opkg
# 2. 写入软件源和公钥，对比已安装版本
# 3. 有更新或未安装时自动安装
#    已装 luci-app-passwall / luci-app-passwall2 就升级已装的那个
#    两个都没装时安装 luci-app-passwall
#    已装的 xray-core、sing-box、chinadns-ng、hysteria、geoview 一并升级
# 4. 再对照 GitHub Releases。luci 包是 all，不看 CPU 架构。
#    25.12 用 25.12+ 的 apk，24.10/23.05 用 23.05-24.10 的 ipk，22.03 用 22.03- 的 ipk。
#    发布页比软件源新时，下载该附件安装。核心组件不在发布页里。
#
# 版本规则：
#   24.10、24.10-SNAPSHOT -> opkg，releases/packages-24.10
#   25.12、25.12-SNAPSHOT -> apk，releases/packages-25.12
#   只有发行版正好是 SNAPSHOT 才用主线快照源
# 下载的索引和公钥暂存在临时目录，退出时删除。软件源配置会留在系统里。
#
#   sh test-passwall-feed.sh
#
# 不在路由器上时，可手动指定（会跳过自动判断）：
#   sh test-passwall-feed.sh --release 24.10 --arch x86_64
#   sh test-passwall-feed.sh --snapshot --arch aarch64_cortex-a53

set -u

BASE="https://master.dl.sourceforge.net/project/openwrt-passwall-build"
FEEDS="passwall_luci passwall_packages passwall2"
RELEASE_FILE="${OPENWRT_RELEASE_FILE:-/etc/openwrt_release}"

REL_ARG=""
ARCH_ARG=""
SNAPSHOT_ARG=0
FORCE=0

usage() {
	echo "用法: sh $0"
	echo "      sh $0 --release 24.10 --arch x86_64"
	echo "      sh $0 --snapshot --arch aarch64_cortex-a53"
	exit 2
}

while [ $# -gt 0 ]; do
	case "$1" in
		--release) REL_ARG="${2:-}"; FORCE=1; shift 2 ;;
		--arch) ARCH_ARG="${2:-}"; FORCE=1; shift 2 ;;
		--snapshot) SNAPSHOT_ARG=1; FORCE=1; shift ;;
		-h|--help) usage ;;
		*) echo "未知参数: $1"; usage ;;
	esac
done

is_num() {
	case "$1" in
		""|*[!0-9]*) return 1 ;;
	esac
	return 0
}

has_cmd() {
	command -v "$1" >/dev/null 2>&1
}

fetch() {
	url="$1"
	dest="$2"
	if has_cmd curl; then
		curl -fsSL --retry 2 --connect-timeout 20 --max-time 120 -o "$dest" "$url"
	elif has_cmd wget; then
		wget -q -O "$dest" "$url"
	else
		echo "需要 curl 或 wget"
		return 1
	fi
}

DISTRIB_ID=""
DISTRIB_RELEASE=""
DISTRIB_ARCH=""
DISTRIB_TARGET=""
SNAPSHOT=0
SERIES=""
PKG_KIND=""
ARCH=""
HAS_APK=0
HAS_OPKG=0

has_cmd apk && HAS_APK=1
has_cmd opkg && HAS_OPKG=1

if [ "$FORCE" -eq 1 ]; then
	ARCH="$ARCH_ARG"
	if [ "$SNAPSHOT_ARG" -eq 1 ]; then
		SNAPSHOT=1
		PKG_KIND="apk"
	else
		SERIES="$REL_ARG"
		case "$SERIES" in
			25.*|26.*|27.*) PKG_KIND="apk" ;;
			*) PKG_KIND="opkg" ;;
		esac
	fi
	if [ -z "$ARCH" ] || { [ "$SNAPSHOT" -eq 0 ] && [ -z "$SERIES" ]; }; then
		usage
	fi
	echo "手动指定，未读 $RELEASE_FILE"
else
	if [ ! -f "$RELEASE_FILE" ]; then
		echo "找不到 $RELEASE_FILE，无法自动判断发行版和架构。"
		echo "请在路由器上执行，或手动加 --release 和 --arch。"
		exit 2
	fi
	# shellcheck disable=SC1090
	. "$RELEASE_FILE"
	ARCH="$DISTRIB_ARCH"
	rel="$DISTRIB_RELEASE"
	echo "ID=$DISTRIB_ID"
	echo "RELEASE=$DISTRIB_RELEASE"
	echo "ARCH=$DISTRIB_ARCH"
	echo "TARGET=$DISTRIB_TARGET"
	echo "本机命令: apk=$([ "$HAS_APK" -eq 1 ] && echo 有 || echo 无) opkg=$([ "$HAS_OPKG" -eq 1 ] && echo 有 || echo 无)"

	if [ -z "$ARCH" ] || [ -z "$rel" ]; then
		echo "发行版文件里没有 DISTRIB_RELEASE 或 DISTRIB_ARCH"
		exit 2
	fi

	# 25.12-SNAPSHOT 仍属于 25.12 分支，不能当成主线 SNAPSHOT。
	case "$rel" in
		SNAPSHOT|snapshot) SNAPSHOT=1 ;;
	esac

	if [ "$SNAPSHOT" -eq 0 ]; then
		major=${rel%%.*}
		rest=${rel#*.}
		minor=${rest%%.*}
		minor=${minor%%-*}
		if ! is_num "$major" || ! is_num "$minor"; then
			echo "无法从 DISTRIB_RELEASE=$rel 解析出版本号"
			exit 2
		fi
		SERIES="${major}.${minor}"
		if [ "$major" -gt 25 ] || { [ "$major" -eq 25 ] && [ "$minor" -ge 12 ]; }; then
			PKG_KIND="apk"
		else
			PKG_KIND="opkg"
		fi
	else
		PKG_KIND="apk"
	fi

	if [ "$PKG_KIND" = "apk" ] && [ "$HAS_APK" -eq 0 ] && [ "$HAS_OPKG" -eq 1 ]; then
		echo "按版本应使用 apk，但这台只有 opkg，改为 opkg。"
		PKG_KIND="opkg"
		if [ "$SNAPSHOT" -eq 1 ]; then
			major=${rel%%.*}
			rest=${rel#*.}
			minor=${rest%%.*}
			minor=${minor%%-*}
			if is_num "$major" && is_num "$minor"; then
				SERIES="${major}.${minor}"
				SNAPSHOT=0
				echo "快照源是 apk 格式，opkg 改用 releases/packages-$SERIES"
			fi
		fi
	fi
	if [ "$PKG_KIND" = "opkg" ] && [ "$HAS_OPKG" -eq 0 ] && [ "$HAS_APK" -eq 1 ]; then
		echo "按版本应使用 opkg，但这台只有 apk，改为 apk。"
		PKG_KIND="apk"
	fi
fi

if [ "$SNAPSHOT" -eq 1 ]; then
	FEED_ROOT="$BASE/snapshots/packages/$ARCH"
	SERIES_LABEL="快照"
else
	FEED_ROOT="$BASE/releases/packages-$SERIES/$ARCH"
	SERIES_LABEL="$SERIES"
fi

echo "判断: 系列=$SERIES_LABEL 架构=$ARCH 包管理器=$PKG_KIND"
echo "软件源根: $FEED_ROOT"
echo

if [ "$PKG_KIND" = "opkg" ] && ! has_cmd gzip; then
	echo "opkg 索引需要 gzip"
	exit 1
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/passwall-feed.XXXXXX")"
cleanup() {
	rm -rf "$TMP"
}
trap cleanup EXIT INT TERM

echo "临时目录: $TMP"
echo "== 公钥 =="
if [ "$PKG_KIND" = "opkg" ]; then
	fetch "$BASE/ipk.pub" "$TMP/ipk.pub" || exit 1
	echo "ipk.pub $(wc -c < "$TMP/ipk.pub" | tr -d ' ') bytes"
else
	fetch "$BASE/apk.pub" "$TMP/apk.pub" || exit 1
	echo "apk.pub $(wc -c < "$TMP/apk.pub" | tr -d ' ') bytes"
fi
echo

fail=0
echo "== 索引 =="
for feed in $FEEDS; do
	if [ "$PKG_KIND" = "apk" ]; then
		url="$FEED_ROOT/$feed/packages.adb"
		dest="$TMP/${feed}.adb"
		if fetch "$url" "$dest"; then
			echo "[ok] $feed $(wc -c < "$dest" | tr -d ' ') bytes"
			echo "     $url"
			grep -a -o 'luci-app-passwall[0-9]*' "$dest" 2>/dev/null | sort -u | while read -r name; do
				echo "     $name"
			done
		else
			echo "[失败] $url"
			fail=1
		fi
		continue
	fi

	url="$FEED_ROOT/$feed/Packages.gz"
	dest="$TMP/${feed}.Packages.gz"
	if ! fetch "$url" "$dest"; then
		echo "[失败] $url"
		fail=1
		continue
	fi
	echo "[ok] $feed $(wc -c < "$dest" | tr -d ' ') bytes"
	gzip -dc "$dest" | awk '
		/^Package: / { pkg = $2; ver = "" }
		/^Version: / { ver = $2 }
		/^$/ {
			if (pkg ~ /^(luci-app-passwall2?|xray-core|sing-box|chinadns-ng|hysteria)$/)
				printf "     %s  %s\n", pkg, ver
			pkg = ""
		}
		END {
			if (pkg ~ /^(luci-app-passwall2?|xray-core|sing-box|chinadns-ng|hysteria)$/)
				printf "     %s  %s\n", pkg, ver
		}
	'
done
echo

is_installed() {
	pkg="$1"
	if [ "$PKG_KIND" = "apk" ]; then
		apk info -e "$pkg" >/dev/null 2>&1
	else
		opkg list-installed "$pkg" 2>/dev/null | grep -q .
	fi
}

opkg_ver() {
	pkg="$1"
	mode="$2"
	if [ "$mode" = "installed" ]; then
		opkg list-installed "$pkg" 2>/dev/null | awk -F ' - ' 'NR==1 { print $2 }'
	else
		opkg list "$pkg" 2>/dev/null | awk -F ' - ' 'NR==1 { print $2 }'
	fi
}

apk_vers() {
	pkg="$1"
	apk list "$pkg" 2>/dev/null | while read -r line; do
		case "$line" in
			"$pkg"-*)
				ver=${line#"$pkg-"}
				ver=${ver%% *}
				case "$line" in
					*"[installed]"*) echo "installed $ver" ;;
					*) echo "available $ver" ;;
				esac
				;;
		esac
	done
}

# 26.9.26-r1 高于 26.9.16-r1，也高于 26.9.1-r1。只按数字段比较。
ver_gt() {
	a=$(printf '%s' "$1" | sed 's/[^0-9][^0-9]*/./g; s/^\.//; s/\.$//')
	b=$(printf '%s' "$2" | sed 's/[^0-9][^0-9]*/./g; s/^\.//; s/\.$//')
	while [ -n "$a" ] || [ -n "$b" ]; do
		aa=${a%%.*}
		bb=${b%%.*}
		[ -n "$aa" ] || aa=0
		[ -n "$bb" ] || bb=0
		if [ "$aa" -gt "$bb" ]; then
			return 0
		fi
		if [ "$aa" -lt "$bb" ]; then
			return 1
		fi
		case "$a" in
			*.*) a=${a#*.} ;;
			*) a="" ;;
		esac
		case "$b" in
			*.*) b=${b#*.} ;;
			*) b="" ;;
		esac
	done
	return 1
}

newest_available() {
	best=""
	while read -r kind ver; do
		[ "$kind" = "available" ] || continue
		if [ -z "$best" ] || ver_gt "$ver" "$best"; then
			best=$ver
		fi
	done << EOF
$1
EOF
	printf '%s' "$best"
}

show_log() {
	log="$1"
	grep -v -E 'ERROR: wget: exited with error|WARNING: updating and opening|^ \[' "$log" || true
	n=$(grep -c "unexpected end of file" "$log" 2>/dev/null || true)
	if [ "${n:-0}" -gt 0 ]; then
		echo "已忽略 ${n} 条无关镜像源错误"
	fi
}

echo "== 配置软件源 =="
if [ "$PKG_KIND" = "apk" ] && [ "$HAS_APK" -eq 1 ]; then
	mkdir -p /etc/apk/keys /etc/apk/repositories.d
	cp "$TMP/apk.pub" /etc/apk/keys/openwrt-passwall-build.pem
	echo "公钥: /etc/apk/keys/openwrt-passwall-build.pem"
	list=/etc/apk/repositories.d/customfeeds.list
	touch "$list"
	for feed in $FEEDS; do
		line="$FEED_ROOT/$feed/packages.adb"
		grep -qxF "$line" "$list" 2>/dev/null || echo "$line" >> "$list"
		echo "$line"
	done
	echo "apk update"
	apk update >"$TMP/update.log" 2>&1 || true
	show_log "$TMP/update.log"
	for feed in $FEEDS; do
		url="$FEED_ROOT/$feed/packages.adb"
		if grep -F "WARNING:" "$TMP/update.log" | grep -F "$url" >/dev/null 2>&1; then
			echo "PassWall 软件源更新失败: $url"
			fail=1
		fi
	done
	if [ "$fail" -eq 0 ] && grep -F "WARNING:" "$TMP/update.log" >/dev/null 2>&1; then
		echo "其他软件源的失败已忽略，PassWall 源可用。"
	fi
elif [ "$PKG_KIND" = "opkg" ] && [ "$HAS_OPKG" -eq 1 ]; then
	opkg-key add "$TMP/ipk.pub"
	echo "公钥已加入 opkg"
	conf=/etc/opkg/customfeeds.conf
	touch "$conf"
	for feed in $FEEDS; do
		line="src/gz $feed $FEED_ROOT/$feed"
		grep -qxF "$line" "$conf" 2>/dev/null || echo "$line" >> "$conf"
		echo "$line"
	done
	echo "opkg update"
	opkg update >"$TMP/update.log" 2>&1 || true
	show_log "$TMP/update.log"
	for feed in $FEEDS; do
		if grep -F "$FEED_ROOT/$feed" "$TMP/update.log" | grep -Ei "failed|error|wget" >/dev/null 2>&1; then
			echo "PassWall 软件源更新失败: $FEED_ROOT/$feed"
			fail=1
		fi
	done
	if [ "$fail" -eq 0 ] && grep -Ei "failed|error|wget" "$TMP/update.log" >/dev/null 2>&1; then
		echo "其他软件源的失败已忽略，PassWall 源可用。"
	fi
else
	echo "本机没有 $PKG_KIND，只完成了环境判断，未安装。"
	echo "临时目录将删除。"
	exit "$fail"
fi

if [ "$fail" -ne 0 ]; then
	echo "软件源更新失败，未安装。"
	exit "$fail"
fi
echo

TARGETS=""
if is_installed luci-app-passwall; then
	TARGETS="$TARGETS luci-app-passwall"
fi
if is_installed luci-app-passwall2; then
	TARGETS="$TARGETS luci-app-passwall2"
fi
if [ -z "$TARGETS" ]; then
	TARGETS="luci-app-passwall"
	echo "未安装 PassWall，将安装 luci-app-passwall"
fi
for core in xray-core sing-box chinadns-ng hysteria geoview; do
	if is_installed "$core"; then
		TARGETS="$TARGETS $core"
	fi
done

echo "== 检查并安装 =="
for pkg in $TARGETS; do
	if [ "$PKG_KIND" = "apk" ]; then
		installed_ver=""
		available_ver=""
		vers="$(apk_vers "$pkg")"
		installed_ver=$(printf '%s\n' "$vers" | awk '$1=="installed" { print $2; exit }')
		available_ver=$(newest_available "$vers")
		if [ -z "$installed_ver" ] && ! is_installed "$pkg"; then
			echo "安装 $pkg"
			apk add --no-network "$pkg" >"$TMP/add.log" 2>&1 || fail=1
			show_log "$TMP/add.log"
		elif [ -n "$installed_ver" ] && [ -n "$available_ver" ] && ver_gt "$available_ver" "$installed_ver"; then
			echo "更新 $pkg：$installed_ver -> $available_ver"
			apk add --no-network -u "$pkg" >"$TMP/add.log" 2>&1 || fail=1
			show_log "$TMP/add.log"
		else
			echo "已是软件源最新 $pkg ${installed_ver:-$available_ver}"
		fi
	else
		if ! is_installed "$pkg"; then
			echo "安装 $pkg"
			opkg install "$pkg" || fail=1
			continue
		fi
		inst="$(opkg_ver "$pkg" installed)"
		echo "检查 $pkg 当前 ${inst:-未知}"
		opkg upgrade "$pkg" || fail=1
		now="$(opkg_ver "$pkg" installed)"
		if [ "$now" != "$inst" ]; then
			echo "更新 $pkg：$inst -> $now"
		else
			echo "已是最新 $pkg ${now:-未知}"
		fi
	fi
done
echo

echo "== GitHub 发布包 =="
echo "https://github.com/Openwrt-Passwall/openwrt-passwall/releases"
want_release=0
for pkg in $TARGETS; do
	[ "$pkg" = "luci-app-passwall" ] && want_release=1
done
if [ "$want_release" -eq 0 ]; then
	echo "未选择 luci-app-passwall，跳过发布页。"
else
	api="https://api.github.com/repos/Openwrt-Passwall/openwrt-passwall/releases/latest"
	if has_cmd curl; then
		curl -fsSL -A "passwall-feed" --retry 2 --connect-timeout 20 --max-time 60 -o "$TMP/release.json" "$api"
	elif has_cmd wget; then
		wget -q -O "$TMP/release.json" "$api"
	fi
	tag=$(sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$TMP/release.json" 2>/dev/null | head -n 1)
	if [ -z "$tag" ]; then
		echo "读发布页失败，软件源结果保持不变。"
	else
		if [ "$PKG_KIND" = "apk" ]; then
			mark="25.12%2B_luci-app-passwall"
			i18nmark="25.12%2B_luci-i18n-passwall"
			ext="apk"
			vers="$(apk_vers luci-app-passwall)"
			inst=$(printf '%s\n' "$vers" | awk '$1=="installed" { print $2; exit }')
		elif [ "$SERIES" = "22.03" ] || [ "$SERIES" = "21.02" ]; then
			mark="22.03-_luci-app-passwall"
			i18nmark="22.03-_luci-i18n-passwall"
			ext="ipk"
			inst="$(opkg_ver luci-app-passwall installed)"
		else
			mark="23.05-24.10_luci-app-passwall"
			i18nmark="23.05-24.10_luci-i18n-passwall"
			ext="ipk"
			inst="$(opkg_ver luci-app-passwall installed)"
		fi
		app_url=$(grep -o 'https://github.com[^" ]*' "$TMP/release.json" | grep '/releases/download/' | grep -F "$mark" | head -n 1)
		i18n_url=$(grep -o 'https://github.com[^" ]*' "$TMP/release.json" | grep '/releases/download/' | grep -F "$i18nmark" | head -n 1)
		echo "发布页 $tag，已安装 ${inst:-无}，附件前缀 $mark"
		if [ -z "$app_url" ]; then
			echo "发布页没有匹配的安装包。"
			fail=1
		elif [ -n "$inst" ] && ! ver_gt "$tag" "$inst"; then
			echo "发布页不高于已安装版本，跳过。"
		else
			echo "下载发布包 $tag"
			if fetch "$app_url" "$TMP/luci-app-passwall.$ext"; then
				if [ "$PKG_KIND" = "apk" ]; then
					apk add --allow-untrusted "$TMP/luci-app-passwall.$ext" >"$TMP/add.log" 2>&1 || fail=1
				else
					opkg install "$TMP/luci-app-passwall.$ext" >"$TMP/add.log" 2>&1 || fail=1
				fi
				show_log "$TMP/add.log"
				if [ -n "$i18n_url" ] && fetch "$i18n_url" "$TMP/luci-i18n-passwall.$ext"; then
					if [ "$PKG_KIND" = "apk" ]; then
						apk add --allow-untrusted "$TMP/luci-i18n-passwall.$ext" >"$TMP/add.log" 2>&1 || true
					else
						opkg install "$TMP/luci-i18n-passwall.$ext" >"$TMP/add.log" 2>&1 || true
					fi
					show_log "$TMP/add.log"
				fi
			else
				echo "下载发布包失败。"
				fail=1
			fi
		fi
	fi
fi
echo
echo "临时目录将删除。"
exit "$fail"
EOF_PW
