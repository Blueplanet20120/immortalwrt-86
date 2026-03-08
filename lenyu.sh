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
