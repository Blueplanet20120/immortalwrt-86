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
