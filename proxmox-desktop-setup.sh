#!/bin/bash
# proxmox-desktop-setup.sh
# Root 專用：Proxmox 桌面環境系統級基礎配置
# 作者：liweilee
set -euo pipefail

echo "==== 更新系統來源 ===="
echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" >> /etc/apt/sources.list
sed -i 's|ftp\.tw\.debian\.org|deb.debian.org|g' /etc/apt/sources.list
sed -i 's/^deb /#deb /' /etc/apt/sources.list.d/pve-enterprise.list 2>/dev/null || true
sed -i 's/^deb /#deb /' /etc/apt/sources.list.d/ceph.list 2>/dev/null || true

echo "==== 執行系統更新 ===="
apt update -y && apt dist-upgrade -y

echo "==== 安裝桌面環境 (XFCE + LightDM) ===="
apt install -y xfce4 lightdm xfce4-terminal thunar-archive-plugin

echo "==== 安裝硬體解碼核心驅動與工具 ===="
# 使用 meta-package 簡化安裝，它會自動拉取所有需要的驅動
apt install -y va-driver-all vainfo
# 標記元套件和工具為手動安裝，防止被 autoremove 誤刪
apt-mark manual va-driver-all vainfo mesa-va-drivers mesa-vulkan-drivers

echo "==== 驗證硬體解碼驅動 ===="
if ! vainfo > /dev/null 2>&1; then
    echo "⚠️  警告：vainfo 執行失敗，VA-API 驅動可能未正確安裝。"
else
    echo "✅ vainfo 驗證通過，硬體解碼驅動已就緒。"
    vainfo | grep -E "VAProfileH264|VAProfileHEVC|VAProfileVP9" | head -5
fi

echo "==== 安裝通用函式庫與工具 ===="
# 基礎函式庫和工具
apt install -y fonts-liberation libu2f-udev xdg-utils gdebi
# 編輯器
apt install -y vim vim-gtk3
# 網路與系統管理工具
apt install -y net-tools curl sudo git
# 檔案系統和網路共享
apt install -y gvfs-backends smbclient samba kio-fuse gvfs-fuse
# 系統監控工具
apt install -y htop glances intel-gpu-tools nvtop lm-sensors psensor
# XFCE 面板外掛和系統工具
apt install -y xfce4-taskmanager xfce4-systemload-plugin xfce4-sensors-plugin
apt install -y gnome-system-monitor gnome-disk-utility
# 影音解碼器和工具
apt install -y ffmpeg libheif-dev libavcodec-extra libavformat-extra
# 輸入法框架和中文字型
apt install -y fcitx5 fcitx5-chewing fcitx5-configtool fonts-noto-cjk

echo "==== 安裝並配置 Flatpak (系統級) ===="
apt install -y flatpak
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

echo "==== 安裝 Flatpak 應用與運行時 ===="
# 瀏覽器和多媒體應用
flatpak install -y flathub \
    org.mozilla.firefox \
    info.smplayer.SMPlayer \
    org.videolan.VLC
# 關鍵媒體運行時（增強編解碼器支援）
flatpak install -y flathub org.freedesktop.Platform.ffmpeg-full

echo "==== 為所有使用者配置 Flatpak 應用權限 (系統級覆寫) ===="
# 使用函數來簡化重複的覆寫命令
set_flatpak_permissions() {
    flatpak override --system "$1" \
        --filesystem=/dev/dri \
        --device=all \
        --env=LIBVA_DRIVER_NAME=iHD \
        --env=FLATPAK_GL_DRIVERS=host \
        --socket=wayland \
        --socket=x11 \
        --socket=pulseaudio
}

# 為各個應用設置硬體加速權限
set_flatpak_permissions org.mozilla.firefox    # Firefox 瀏覽器
set_flatpak_permissions info.smplayer.SMPlayer # SMPlayer 播放器
set_flatpak_permissions org.videolan.VLC       # VLC 播放器

echo "==== 配置 Flatpak 所需的核心權限 (用戶命名空間) ===="
echo "kernel.unprivileged_userns_clone=1" > /etc/sysctl.d/99-flatpak-userns.conf
sysctl -p /etc/sysctl.d/99-flatpak-userns.conf

echo "==== 為所有新使用者配置輸入法自動啟動模板 ===="
mkdir -p /etc/skel/.config/autostart/
cp /usr/share/applications/org.fcitx.Fcitx5.desktop /etc/skel/.config/autostart/

echo "==== 系統服務與底層配置 ===="
# 設定 chrony 關機超時
mkdir -p /etc/systemd/system/chrony.service.d
cat << EOF > /etc/systemd/system/chrony.service.d/override.conf
[Service]
TimeoutStopSec=10s
EOF
systemctl daemon-reexec

# 設定預設啟動目標為圖形界面
systemctl set-default graphical.target

# 設定 vim 為預設編輯器
update-alternatives --set editor /usr/bin/vim.basic

echo "==== 更新 initramfs 與 grub ===="
sed -i 's/^MODULES=.*/MODULES=dep/' /etc/initramfs-tools/initramfs.conf
sed -i 's/^COMPRESS=.*/COMPRESS=xz/' /etc/initramfs-tools/initramfs.conf
update-initramfs -u
update-grub

echo ""
echo "✅ Proxmox Desktop 系統級基礎配置已完成！"
echo "=================================================="
echo "下一步操作指引："
echo "1. 建立日常使用者帳號: adduser <username>"
echo "2. 將其加入 sudo 群組: usermod -aG sudo <username>"
echo "3. 切換至該使用者: su - <username>"
echo "4. 執行 proxmox-desktop-setup-user.sh"
echo "5. 重新啟動系統以套用所有變更: reboot"
echo "=================================================="
echo "⭐ 本腳本已完成之系統級配置摘要："
echo "   - 硬體解碼驅動 (VA-API) 安裝與驗證"
echo "   - Flatpak 環境與應用 (Firefox, SMPlayer, VLC) 安裝"
echo "   - 系統級 Flatpak 權限覆寫 (硬體加速)"
echo "   - 核心權限 (user namespaces) 開啟"
echo "   - 輸入法框架 (Fcitx5) 安裝與新使用者模板"
echo "   - 各類常用系統工具與影音基礎套件"
echo "=================================================="
