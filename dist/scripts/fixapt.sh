#!/bin/bash
set -e

# 删除原有 status 文件
rm -f /var/lib/dpkg/status

# 下载新的 status 文件
wget -O /var/lib/dpkg/status http://static2.fnnas.com/aptfix/status

# 更新软件包索引
apt update

echo "安装所需依赖"
# 安装所需软件包
DEBIAN_FRONTEND=noninteractive apt install -y -o Dpkg::Options::="--force-confold" \
    quotatool patchelf libinih-dev acl jq \
    openvswitch-switch openvswitch-switch-dpdk \
    libvirt-daemon-system python3.11-venv python3-pip \
    msr-tools clinfo libid3tag0 libogg-dev libvorbis-dev libflac-dev \
    lshw upower libsmbios-dev hwinfo nut \
    plymouth plymouth-themes wayland-protocols libwayland-dev weston qtwayland5 \
    libqtermwidget5-1 containerd.io docker-buildx-plugin \
    docker-ce docker-ce-cli docker-ce-rootless-extras docker-compose-plugin

echo "安装完成"

echo "修复安装元信息"
rm -rf /var/lib/dpkg/info_old
mv /var/lib/dpkg/info /var/lib/dpkg/info_old
mkdir /var/lib/dpkg/info

echo "更新索引"
apt update

apt -f install


kernel_version="$(uname -r)"
deb_kernel_name="linux-image-${kernel_version}"


if dpkg -s "$deb_kernel_name" >/dev/null 2>&1; then
  echo "[OK] $deb_kernel_name 已存在于 dpkg 状态中，无需修复。"
else
  echo "[FIX] 未检测到 $deb_kernel_name，正在构建占位包以修复 dpkg 状态..."

  PACKAGE_NAME="$deb_kernel_name"
  PACKAGE_VERSION="$kernel_version"

  TEMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$TEMP_DIR"' EXIT

  cd "$TEMP_DIR"
  mkdir -p DEBIAN

  # control 文件必须顶格写
  cat > DEBIAN/control <<EOF
Package: $PACKAGE_NAME
Version: $PACKAGE_VERSION
Architecture: all
Maintainer: anna <devops@fnnas.com>
Description: TRIM NAS Kernel (placeholder to fix dpkg status)
EOF

  out_deb="/tmp/for_fix_dpkg.deb"
  dpkg-deb --build . "$out_deb"
  dpkg -i "$out_deb"

  echo "[DONE] 占位包 $PACKAGE_NAME ($PACKAGE_VERSION) 已安装。"
fi


echo "修复完成"