#!/bin/bash
set -e

PKG_NAME="proxmox-desktop-setup"
VERSION="1.0"
ARCH="all"
DEB_DIR="deb-build"

echo "📦 準備打包 $PKG_NAME.deb"

rm -rf $DEB_DIR
mkdir -p $DEB_DIR/DEBIAN
mkdir -p $DEB_DIR/usr/local/bin

cp setup-proxmox-desktop.sh $DEB_DIR/usr/local/bin/$PKG_NAME
chmod +x $DEB_DIR/usr/local/bin/$PKG_NAME

cat <<EOF > $DEB_DIR/DEBIAN/control
Package: $PKG_NAME
Version: $VERSION
Section: utils
Priority: optional
Architecture: $ARCH
Maintainer: liweilee <你的信箱>
Description: 一鍵安裝 Proxmox Desktop 桌面環境、中文輸入法與常用工具
EOF

dpkg-deb --build $DEB_DIR
mv deb-build.deb ${PKG_NAME}_${VERSION}_${ARCH}.deb
echo "✅ 已產生 ${PKG_NAME}_${VERSION}_${ARCH}.deb"
