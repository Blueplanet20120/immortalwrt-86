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

# backup config
cat>>/etc/sysupgrade.conf<<-EOF
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


cat>rename.sh<<-\EOF
#!/bin/bash

# 清理旧文件
rm -rf bin/targets/x86/64/config.buildinfo
rm -rf bin/targets/x86/64/feeds.buildinfo
rm -rf bin/targets/x86/64/immortalwrt-x86-64-generic-kernel.bin
rm -rf bin/targets/x86/64/immortalwrt-x86-64-generic-squashfs-rootfs.img.gz
rm -rf bin/targets/x86/64/immortalwrt-x86-64-generic-rootfs.tar.gz
rm -rf bin/targets/x86/64/immortalwrt-x86-64-generic.manifest
rm -rf bin/targets/x86/64/sha256sums
rm -rf bin/targets/x86/64/profiles.json
rm -rf bin/targets/x86/64/version.buildinfo
rm -rf bin/targets/x86/64/immortalwrt-x86-64-generic-ext4-rootfs.img.gz
rm -rf bin/targets/x86/64/immortalwrt-x86-64-generic-ext4-combined-efi.img.gz
rm -rf bin/targets/x86/64/immortalwrt-x86-64-generic-ext4-combined.img.gz
sleep 2

# 读取版本号与内核补丁版本
rename_version=$(cat files/etc/lenyu_version)
str1=$(grep "KERNEL_PATCHVER:=" target/linux/x86/Makefile | cut -d '=' -f2)

# 动态获取补丁小版本
kernel_include_file="include/kernel-${str1}"
if [ -f "$kernel_include_file" ]; then
    ver=$(grep "LINUX_VERSION-${str1} =" "$kernel_include_file" | cut -d '.' -f3)
else
    ver=""
fi

# 定义源镜像和目标名称前缀
src_img=bin/targets/x86/64/immortalwrt-x86-64-generic-squashfs-combined.img.gz
src_efi=bin/targets/x86/64/immortalwrt-x86-64-generic-squashfs-combined-efi.img.gz
base="immortalwrt_x86-64-${rename_version}_${str1}.${ver}"

# 重命名镜像，添加存在性检查
if [ -f "$src_img" ] && [ -f "$src_efi" ]; then
    mv "$src_img"   "bin/targets/x86/64/${base}_sta_Lenyu.img.gz"
    mv "$src_efi"   "bin/targets/x86/64/${base}_uefi-gpt_sta_Lenyu.img.gz"
else
    echo "镜像文件不存在，无法重命名：$src_img 或 $src_efi"
fi

# 生成版本列表
ls bin/targets/x86/64 | grep "gpt_sta_Lenyu.img" | cut -d '-' -f3 | cut -d '_' -f1-2 > wget/op_version1

# 生成 MD5 列表
ls -1 bin/targets/x86/64 > wget/open_sta_md5
sta_version=$(grep "_uefi-gpt_sta_Lenyu.img.gz" wget/open_sta_md5 | cut -d '-' -f3 | cut -d '_' -f1-2)
immortalwrt_sta=immortalwrt_x86-64-${sta_version}_sta_Lenyu.img.gz
immortalwrt_sta_uefi=immortalwrt_x86-64-${sta_version}_uefi-gpt_sta_Lenyu.img.gz

# 切换目录并生成 MD5 文件
cd bin/targets/x86/64 || exit 1
md5sum "$immortalwrt_sta" > immortalwrt_sta.md5
md5sum "$immortalwrt_sta_uefi" > immortalwrt_sta_uefi.md5

exit 0
EOF

cat>lenyu.sh<<-\EOOF
#!/bin/bash
lenyu_version="`date '+%y%m%d%H%M'`_sta_Len yu" 
echo $lenyu_version >  wget/DISTRIB_REVISION1 
echo $lenyu_version | cut -d _ -f 1 >  files/etc/lenyu_version  
new_DISTRIB_REVISION=`cat  wget/DISTRIB_REVISION1`
#
grep "Check_Update.sh"  package/emortal/default-settings/files/99-default-settings
if [ $? != 0 ]; then
	sed -i 's/exit 0/ /'  package/emortal/default-settings/files/99-default-settings
	cat>> package/emortal/default-settings/files/99-default-settings<<-EOF
	sed -i '$ a alias lenyu="sh /usr/share/Check_Update.sh"' /etc/profile
	sed -i '/DISTRIB_DESCRIPTION/d' /etc/openwrt_release
	echo "DISTRIB_DESCRIPTION='$new_DISTRIB_REVISION'" >> /etc/openwrt_release
	exit 0
	EOF
fi
grep "Lenyu-auto.sh"  package/emortal/default-settings/files/99-default-settings
if [ $? != 0 ]; then
	sed -i 's/exit 0/ /'  package/emortal/default-settings/files/99-default-settings
	cat>> package/emortal/default-settings/files/99-default-settings<<-EOF
	sed -i '$ a alias lenyu-auto="sh /usr/share/Lenyu-auto.sh"' /etc/profile
	exit 0
	EOF
fi

grep "Lenyu-pw.sh"  package/emortal/default-settings/files/99-default-settings
if [ $? != 0 ]; then
	sed -i 's/exit 0/ /'  package/emortal/default-settings/files/99-default-settings
	cat>> package/emortal/default-settings/files/99-default-settings<<-EOF
	sed -i '$ a alias lenyu-pw="sh /usr/share/Lenyu-pw.sh"' /etc/profile
	exit 0
	EOF
fi

grep "backup.tar.gz"  package/emortal/default-settings/files/99-default-settings
if [ $? != 0 ]; then
	sed -i 's/exit 0/ /'  package/emortal/default-settings/files/99-default-settings
	cat>> package/emortal/default-settings/files/99-default-settings<<-\EOF
	######添加定时执行rc.local任务
	# 检查 /etc/crontabs/root 中 rc.local 的出现次数
	RC_COUNT=$(grep -c "rc.local" /etc/crontabs/root)
	
	# 删除多余的 rc.local 条目
	if [ "$RC_COUNT" -gt 1 ]; then
	    awk '/rc.local/ && !seen {print; seen=1; next} !/rc.local/' /etc/crontabs/root > tmpfile && mv tmpfile /etc/crontabs/root
	    echo "Removed extra rc.local entries, kept one" >> /tmp/restore.log
	elif [ "$RC_COUNT" -eq 0 ]; then
	    # 如果没有 rc.local，添加一条
	    echo "@reboot sleep 60 && bash /etc/rc.local > /dev/null 2>&1 &" >> /etc/crontabs/root
	    echo "Add rc.local succeeded" >> /tmp/restore.log
	else
	    # 如果只存在一条
	    echo "rc.local already exists, no action taken" >> /tmp/restore.log
	fi
	#####
	cat> /etc/rc.local<<-\EOFF
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
	# 调用 get_smallest_mounted_disk 函数并将结果存储到变量 disk_path 中
	disk_path=$(get_smallest_mounted_disk)
	if [ -f ${disk_path}/custom-backup.tar.gz ]; then
 		echo "Restore script already exists: /tmp/custom-backup.tar.gz"
		echo "Performing Restore..."
		bash /usr/share/custom-restore.sh
		echo "Restore completed."
		echo "Restore successful $(date '+%Y-%m-%d %H:%M:%S')" >> /tmp/restore.log
		
		# Restart Passwall service
		/etc/init.d/passwall restart
		exit 0
	else
		echo "Restore failed $(date '+%Y-%m-%d %H:%M:%S')" >> /tmp/restore.log
		exit 1
	fi
	
		exit 0
		EOFF
	exit 0
	EOF
fi

EOOF

cat>files/usr/share/Check_Update.sh<<-\EOF
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

cat>files/usr/share/Lenyu-auto.sh<<-\EOF
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

cat>files/usr/share/Lenyu-pw.sh<<-\EOF
#!/bin/sh
# Define variables
TEMP_DIR="/tmp/test"
PSVERSION_FILE="/usr/share/psversion"
UNZIP_URL="https://downloads.openwrt.org/releases/packages-23.05/x86_64/packages/unzip_6.0-8_x86_64.ipk"
UNZIP_PACKAGE="unzip_6.0-8_x86_64.ipk"
RED='\033[0;31m'    # Red color
BLUE='\033[0;34m'   # Blue color
ORANGE='\033[0;33m' # Orange color
NC='\033[0m'        # No Color (reset)

# Echo message in red color
echo_red() {
  echo -e "${RED}$1${NC}"
}

# Echo message in blue color
echo_blue() {
  echo -e "${BLUE}$1${NC}"
}

# Echo message in orange color
echo_orange() {
  echo -e "${ORANGE}$1${NC}"
}

# Preparing for update (blue message)
echo_blue "正在做更新前的准备工作..."
# 检查 unzip 是否已安装
if opkg list-installed | grep -q unzip; then
    echo "unzip 已经安装，跳过安装步骤。"
else
    # 下载 unzip 包
    echo "开始下载 unzip 包..."
    wget -q --show-progress "$UNZIP_URL" -O "$UNZIP_PACKAGE"

    # 检查下载是否成功
    if [ $? -eq 0 ]; then
        echo "下载成功，开始安装 unzip 包..."
        opkg install "$UNZIP_PACKAGE"
        
        # 检查安装是否成功
        if [ $? -eq 0 ]; then
            echo "unzip 安装成功！"
        else
            echo "unzip 安装失败！"
        fi
    else
        echo "unzip 下载失败！"
    fi
fi

# Create temporary directory
mkdir -p "$TEMP_DIR"

# Get the latest release information from GitHub
latest_release=$(curl -s https://api.github.com/repos/xiaorouji/openwrt-passwall/releases/latest)

# Extract version number from GitHub release (例如 "25.3.9-1")
version=$(echo "$latest_release" | grep '"tag_name":' | sed -E 's/.*"tag_name": "([^"]+)".*/\1/')


# Extract download URLs
luci_app_passwall_url=$(echo "$latest_release" | grep -o '"browser_download_url": "[^"]*luci-24.10_luci-app-passwall_[^"]*"' | sed -E 's/.*"browser_download_url": "([^"]+)".*/\1/')
luci_i18n_passwall_url=$(echo "$latest_release" | grep -o '"browser_download_url": "[^"]*luci-24.10_luci-i18n-passwall-zh-cn_[^"]*"' | sed -E 's/.*"browser_download_url": "([^"]+)".*/\1/')

# 获取文件名（例如 luci-24.10_luci-app-passwall_25.3.9-r1_all.ipk）
app_file=$(basename "$luci_app_passwall_url")
i18n_file=$(basename "$luci_i18n_passwall_url")

# 从 app_file 中提取版本号部分，即 "25.3.9-r1"
version2410=$(echo "$app_file" | sed -E 's/^luci-24\.10_luci-app-passwall_([^_]+)_all\.ipk$/\1/')
echo_blue "最新云端版本号：$version2410"

# 将当前安装的版本写入 psversion 文件
opkg list-installed | grep luci-app-passwall | awk '{print $3}' > "$PSVERSION_FILE"
installed_version=$(cat "$PSVERSION_FILE" 2>/dev/null)
echo_blue "最新本地版本号：$installed_version"

# 检查版本是否已经是最新的，比较时使用 version2410 变量
if [ "$installed_version" = "$version2410" ]; then
  echo_red "已经是最新版本，还更新个鸡毛啊！"
  exit 0
fi

# 如果版本不一致，提示用户确认（10秒倒计时，默认 y）
echo_orange "你即将更新 passwall 为最新版本：$version2410，确定更新吗？(y/n, 回车默认y，10秒后自动执行y)"
read -t 10 -r confirmation
confirmation=${confirmation:-y}

if [ "$confirmation" != "y" ]; then
  echo_blue "已取消更新。"
  exit 0
fi

# 用户确认后继续更新
echo_blue "新版本可用，开始更新..."

# 下载文件到临时目录（保持原文件名）
wget -O "$TEMP_DIR/$app_file" "$luci_app_passwall_url"
wget -O "$TEMP_DIR/$i18n_file" "$luci_i18n_passwall_url"
sleep 5
echo "下载完成:"
echo "$TEMP_DIR/$app_file"
echo "$TEMP_DIR/$i18n_file"

# 安装下载的 IPK 包
sleep 1
/etc/init.d/passwall stop
opkg install "$TEMP_DIR/$app_file" --force-overwrite
opkg install "$TEMP_DIR/$i18n_file" --force-overwrite

# 重启 passwall 服务
/etc/init.d/passwall restart

# 将新版本号（version2410）写入 psversion 文件
echo "$version2410" > "$PSVERSION_FILE"

echo_blue "插件已安装并且 passwall 服务已重启。"

# 清理临时目录
rm -rf "$TEMP_DIR"

exit 0

EOF

cat> files/usr/share/custom-backup.sh<<-\EOF  
#!/bin/sh
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
# 调用 get_smallest_mounted_disk 函数并将结果存储到变量 disk_path 中
disk_path=$(get_smallest_mounted_disk)

BACKUP_DIR="${disk_path}/custom-backup"
BACKUP_FILE="${disk_path}/custom-backup.tar.gz"

# 创建备份目录
mkdir -p $BACKUP_DIR

# 使用 tar 命令直接备份文件和目录，保留目录结构
tar -czvf $BACKUP_FILE \
    /usr/bin/xray \
    /usr/share/v2ray/geoip.dat \
    /usr/share/passwall/rules \
    /usr/share/v2ray/geosite.dat

# 检查备份是否成功
if [ $? -eq 0 ]; then
    echo "Backup successful: $BACKUP_FILE"
else
    echo "Backup failed"
fi

# 清理临时备份目录
rm -rf $BACKUP_DIR
exit 0
EOF

cat>files/usr/share/custom-restore.sh<<-\EOF
#!/bin/sh
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
# 调用 get_smallest_mounted_disk 函数并将结果存储到变量 disk_path 中
disk_path=$(get_smallest_mounted_disk)

# 构建 BACKUP_FILE 路径并输出
BACKUP_FILE="${disk_path}/custom-backup.tar.gz"
TEMP_RESTORE_DIR="${disk_path}/restore-tmp"

# 检查备份文件是否存在
if [ ! -f "$BACKUP_FILE" ]; then
    echo "Backup file not found: $BACKUP_FILE"
    exit 1
fi

# 创建临时恢复目录
mkdir -p "$TEMP_RESTORE_DIR"

# 解压备份文件到临时恢复目录
tar -xzvf "$BACKUP_FILE" -C "$TEMP_RESTORE_DIR"

# 检查解压是否成功
if [ $? -ne 0 ]; then
    echo "Extraction failed"
    rm -rf "$TEMP_RESTORE_DIR"
    exit 1
fi

# 创建目标目录
mkdir -p /usr/share/v2ray/

# 复制文件到系统对应位置
cp -r "$TEMP_RESTORE_DIR/usr/bin/xray" "/usr/bin/xray"
cp -r "$TEMP_RESTORE_DIR/usr/share/v2ray/geoip.dat" "/usr/share/v2ray/geoip.dat"
cp -r "$TEMP_RESTORE_DIR/usr/share/v2ray/geosite.dat" "/usr/share/v2ray/geosite.dat"

# 检查复制是否成功
if [ $? -eq 0 ]; then
    echo "Restore successful"
else
    echo "Restore failed"
fi

# 清理临时恢复目录
rm -rf "$TEMP_RESTORE_DIR"

# 清理备份文件
rm -rf "$BACKUP_FILE"
exit 0
EOF

