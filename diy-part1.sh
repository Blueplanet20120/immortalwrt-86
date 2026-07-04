
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


cat>rename.sh<<-\EOF
#!/bin/bash

TARGET_DIR="bin/targets/x86/64"

# 1. 兜底检查，确保在正确的上下文中执行
if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: 找不到 $TARGET_DIR，请确认脚本是否在 openwrt 根目录下执行。"
    exit 1
fi

# 确保存放 version 记录的目录存在
mkdir -p wget

# 2. 批量清理冗余文件（使用通配符替代逐行硬编码，更简洁且容错率高）
rm -f ${TARGET_DIR}/*.buildinfo
rm -f ${TARGET_DIR}/*.manifest
rm -f ${TARGET_DIR}/sha256sums
rm -f ${TARGET_DIR}/profiles.json
rm -f ${TARGET_DIR}/*-kernel.bin
rm -f ${TARGET_DIR}/*-rootfs.*
rm -f ${TARGET_DIR}/*-ext4-*.img.gz

# 3. 读取前面 lenyu.sh 注入的自定义版本号
if [ -f "files/etc/lenyu_version" ]; then
    rename_version=$(cat files/etc/lenyu_version)
else
    rename_version="unknown"
    echo "Warning: files/etc/lenyu_version 未找到，使用默认版本号 fallback。"
fi

# 4. 动态解析内核大版本与补丁号 (增强正则与去空格处理)
kernel_patchver=$(grep "KERNEL_PATCHVER:=" target/linux/x86/Makefile | cut -d '=' -f2 | tr -d ' ')
kernel_include_file="include/kernel-${kernel_patchver}"

if [ -f "$kernel_include_file" ]; then
    # 提取类似 LINUX_VERSION-6.6 = .32 中的 32
    kernel_subver=$(grep "^LINUX_VERSION-${kernel_patchver}" "$kernel_include_file" | awk -F'.' '{print $NF}' | tr -d ' ')
    [ -n "$kernel_subver" ] && ver=".${kernel_subver}" || ver=""
else
    ver=""
fi

# 5. 组合最终的文件名 Base
base_name="immortalwrt_x86-64-${rename_version}_${kernel_patchver}${ver}"

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
echo "${base_name}_sta_Lenyu" > wget/op_version1
ls -1 ${TARGET_DIR} > wget/open_sta_md5

exit 0
EOF

cat>lenyu.sh<<-\EOOF
#!/bin/bash

# 1. 预先创建需要的目录，防止报错
mkdir -p wget files/etc

# 2. 生成版本号 (统一使用下划线代替不规范的空格，保证变量安全性)
lenyu_version="$(date '+%y%m%d%H%M')_sta_Len_yu" 
echo "$lenyu_version" > wget/DISTRIB_REVISION1 
echo "$lenyu_version" | cut -d _ -f 1 > files/etc/lenyu_version  
new_DISTRIB_REVISION=$(cat wget/DISTRIB_REVISION1)

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
set -u
set -o pipefail

########################################
# 基础配置与路径
########################################
TEMP_DIR="/tmp/passwall_update"
RULE_DIR="/usr/share/passwall/rules"
RULE_BACKUP="/tmp/passwall_rule_backup"
LOCKDIR="/tmp/passwall-update.lock"
TIME_MARKFILE="/tmp/passwall_opkg_update.time"
CACHE_TTL=604800

RED='\033[0;31m'; BLUE='\033[0;34m'; ORANGE='\033[0;33m'; NC='\033[0m'
echo_red(){ echo -e "${RED}$1${NC}"; }
echo_blue(){ echo -e "${BLUE}$1${NC}"; }
echo_orange(){ echo -e "${ORANGE}$1${NC}"; }

########################################
# 0. 并发锁与清理机制
########################################
if ! mkdir "$LOCKDIR" 2>/dev/null; then
  echo_red "==> 另一个更新任务正在运行中，请稍后再试"
  exit 1
fi

# 异常退出时的清理收尾
cleanup() {
  rm -rf "$TEMP_DIR" 2>/dev/null
  rm -rf "$RULE_BACKUP" 2>/dev/null
  rmdir "$LOCKDIR" 2>/dev/null
}
trap cleanup EXIT INT TERM

echo_blue "== Passwall 官方 OPKG 源热更新脚本 =="

########################################
# 1. 记录已安装的后端
########################################
echo_blue "检测已安装的后端组件..."
BACKENDS="sing-box xray-core v2ray-plugin haproxy ipt2socks geoview"
SAVED_BACKENDS=""
for p in $BACKENDS; do
  if opkg list-installed | awk '{print $1}' | grep -qx "$p"; then
    SAVED_BACKENDS="$SAVED_BACKENDS $p"
  fi
done

########################################
# 2. 智能缓存时效判定
########################################
UPDATE_FLAG=0
current_time=$(date +%s)

if [ -f "$TIME_MARKFILE" ] && [ -f "/var/opkg-lists/passwall_luci" ]; then
  last_update=$(cat "$TIME_MARKFILE" 2>/dev/null || echo 0)
  age=$((current_time - last_update))
  
  if [ "$age" -lt "$CACHE_TTL" ]; then
    echo_blue "检测到本地软件源索引缓存未过期（小于 $((CACHE_TTL / 3600)) 小时），跳过下载与环境刷新。"
    UPDATE_FLAG=1
  fi
fi

########################################
# 3. 动态配置源与同步索引（仅在缓存失效时触发）
########################################
if [ "$UPDATE_FLAG" -eq 0 ]; then
  echo_blue "配置官方签名公钥..."
  mkdir -p "$TEMP_DIR"
  if ! wget -q -O "$TEMP_DIR/ipk.pub" -T 15 -t 3 https://master.dl.sourceforge.net/project/openwrt-passwall-build/ipk.pub; then
    echo_red "下载官方公钥失败，请检查网络连通性。"
    exit 1
  fi
  opkg-key add "$TEMP_DIR/ipk.pub"

  echo_blue "正在生成并校验官方软件源配置..."
  read release arch << EOF
$(. /etc/openwrt_release ; echo $(echo "$DISTRIB_RELEASE" | cut -d. -f1-2 | cut -d- -f1) $DISTRIB_ARCH)
EOF

  if [ -z "$release" ] || [ -z "$arch" ]; then
    echo_red "无法获取系统架构或版本信息，终止执行。"
    exit 1
  fi

  # 擦除任何历史残留的 passwall 重复源
  sed -i '/passwall_luci/d; /passwall_packages/d; /passwall2/d' /etc/opkg/customfeeds.conf
  sed -i '/packages-24\//d' /etc/opkg/customfeeds.conf

  # 写入规范的版本路径
  for feed in passwall_luci passwall_packages passwall2; do
    echo "src/gz $feed https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-$release/$arch/$feed" >> /etc/opkg/customfeeds.conf
  done

  echo_blue "正在同步 OPKG 软件源索引..."
  if ! opkg update; then
    echo_red "软件源索引更新失败，请检查网络或 URL 连通性。"
    exit 1
  fi
  # 只有成功 update 后，才写回私有时间戳
  echo "$current_time" > "$TIME_MARKFILE"
fi

########################################
# 4. 精确版本比对
########################################
# 精确抓取本地已安装版本
installed_version="$(opkg list-installed | grep '^luci-app-passwall ' | awk '{print $3}')"

# 精确抓取软件源中最新候选版本，并强制只取返回的第一行最高版本
available_version="$(opkg info luci-app-passwall | grep '^Version:' | awk '{print $2}' | head -n 1)"

installed_version="${installed_version:-未安装}"
available_version="${available_version:-未知}"

echo_blue "最新源版本：$available_version"
echo_blue "当前已安装：$installed_version"

if [ "$installed_version" = "$available_version" ] && [ "$installed_version" != "未安装" ]; then
  echo_blue "版本已是最新，无需更新。"
  exit 0
fi

########################################
# 5. 用户确认
########################################
echo_orange "即将通过官方源部署/更新到 $available_version，继续？(y/n, 默认 y)"
read -t 10 -r reply || true
reply=${reply:-y}
if [ "$reply" != "y" ]; then
  echo_blue "已取消。"
  exit 0
fi

########################################
# 6. 备份自定义规则
########################################
echo_blue "备份自定义规则..."
mkdir -p "$RULE_BACKUP"
for f in direct_host direct_ip proxy_host; do
  [ -f "$RULE_DIR/$f" ] && cp "$RULE_DIR/$f" "$RULE_BACKUP/$f"
done

########################################
# 7. 停止 Passwall + 精准清理网络链
########################################
echo_blue "安全挂起服务并精准清理网络规则..."
/etc/init.d/passwall stop 2>/dev/null || true
sleep 1

for table in passwall passwall_chn passwall_geo passwall1; do
  nft delete table inet "$table" 2>/dev/null || true
done

########################################
# 8. 执行 OPKG 包安装
########################################
echo_blue "正在调度 OPKG 进行包部署与升级..."
opkg install luci-app-passwall --force-overwrite --force-reinstall 2>&1 | \
  grep -v "Not deleting modified conffile" || true

# 自动处理中文语言包的同步升级
if opkg list-installed | grep -q "luci-i18n-passwall-zh-cn"; then
  opkg install luci-i18n-passwall-zh-cn --force-overwrite --force-reinstall 2>&1 | \
    grep -v "Not deleting modified conffile" || true
fi

########################################
# 9. 恢复自定义规则
########################################
echo_blue "还原用户自定义规则..."
for f in direct_host direct_ip proxy_host; do
  [ -f "$RULE_BACKUP/$f" ] && cp "$RULE_BACKUP/$f" "$RULE_DIR/$f"
done

########################################
# 10. 恢复缺失的后端组件
########################################
echo_blue "校验后端生态依赖状态..."
for p in $SAVED_BACKENDS; do
  if ! opkg list-installed | awk '{print $1}' | grep -qx "$p"; then
    echo_orange "发现核心缺失，尝试重回装后端：$p"
    opkg install "$p" --force-overwrite
  fi
done

########################################
# 11. 防火墙重载与热启动
########################################
echo_blue "重载系统防火墙核心 (fw4)..."
/etc/init.d/firewall restart >/dev/null 2>&1
sleep 2

echo_blue "拉起 Passwall 服务进程..."
/etc/init.d/passwall restart 2>/dev/null || true

echo_blue "重启本地 DNS 转发服务 (dnsmasq)..."
/etc/init.d/dnsmasq restart >/dev/null 2>&1 || true

echo_blue "清理残留的网络连接跟踪 (Conntrack)..."
if command -v conntrack >/dev/null 2>&1; then
  conntrack -F >/dev/null 2>&1 || true
else
  (echo 1 > /proc/sys/net/netfilter/nf_conntrack_tcp_loose) 2>/dev/null || true
  (echo 1 > /proc/sys/net/ipv4/netfilter/ip_conntrack_tcp_loose) 2>/dev/null || true
fi

echo_blue "=== 官方 OPKG 源热升级流完成，网络已无缝接管 ==="
exit 0
EOF
