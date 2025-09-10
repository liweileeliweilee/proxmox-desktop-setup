#!/bin/bash
set -e

echo "==== 更新來源 ===="
echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" >> /etc/apt/sources.list
echo "==== 修正 sources.list 中的 Debian 鏡像來源 ===="
sed -i 's|ftp\.tw\.debian\.org|deb.debian.org|g' /etc/apt/sources.list

echo "==== 註解 enterprise/ceph 套件來源 ===="
sed -i 's/^deb /#deb /' /etc/apt/sources.list.d/pve-enterprise.list 2>/dev/null || true
sed -i 's/^deb /#deb /' /etc/apt/sources.list.d/ceph.list 2>/dev/null || true

echo "==== 系統更新 ===="
apt update -y && apt dist-upgrade -y

echo "==== 安裝桌面環境 XFCE + LightDM ===="
apt install -y xfce4 lightdm xfce4-terminal thunar-archive-plugin

echo "==== 安裝硬體解碼核心驅動與工具 (最優先) ===="
apt install -y intel-media-va-driver libva-glx2 libva-x11-2 libva-drm2 libva-wayland2 libva-dev vainfo
echo "==== 標記硬體解碼套件，防止被 autoremove 移除 ===="
apt-mark manual intel-media-va-driver libva-glx2 libva-x11-2 libva-drm2 libva-wayland2 libva-dev vainfo
apt-mark manual mesa-va-drivers mesa-vulkan-drivers # 保護圖形相關核心庫

echo "==== 驗證硬體解碼驅動安裝成功 ===="
if ! vainfo > /dev/null 2>&1; then
    echo "⚠️  警告：vainfo 執行失敗，VAAPI 驅動可能未正確安裝。"
else
    echo "✅ vainfo 驗證通過，硬體解碼驅動已就緒。"
    vainfo | grep -E "VAProfileH264|VAProfileHEVC|VAProfileVP9" | head -5
fi

echo "==== 安裝 Firefox/Chrome 依賴與瀏覽器 ===="
# 安裝瀏覽器所需的通用函式庫
apt install -y fonts-liberation libu2f-udev xdg-utils

# 下載並導入 Mozilla 公鑰
mkdir -p /etc/apt/keyrings
wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- | sudo tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" | sudo tee /etc/apt/sources.list.d/mozilla.list > /dev/null
apt update
apt install -y firefox

# 安裝 Chrome
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
apt install -y ./google-chrome-stable_current_amd64.deb
rm google-chrome-stable_current_amd64.deb

echo "==== 安裝影音播放工具與相關套件 ===="
apt install -y smplayer libheif-dev ffmpeg libavcodec-extra libavformat-extra
# va-driver-all 可選安裝，因為已明確安裝Intel驅動
apt install -y va-driver-all
apt-mark manual va-driver-all

echo "==== 安裝字型與輸入法 ===="
apt install -y fonts-noto-cjk fcitx5 fcitx5-chewing fcitx5-configtool

echo "==== 設定 fcitx5 環境變數與自動啟動 ===="
echo 'GTK_IM_MODULE=fcitx' >> /etc/environment
echo 'QT_IM_MODULE=fcitx' >> /etc/environment
echo 'XMODIFIERS=@im=fcitx' >> /etc/environment
mkdir -p ~/.config/autostart
cp /usr/share/applications/org.fcitx.Fcitx5.desktop ~/.config/autostart/

echo "==== 設定預設語言為繁體中文 ===="
echo 'LANG=zh_TW.UTF-8' >> /etc/environment

echo "==== 安裝其他常用工具 ===="
apt install -y net-tools vim curl sudo gdebi vim-gtk3 gvfs-backends smbclient samba kio-fuse gvfs-fuse xfce4-taskmanager xfce4-systemload-plugin htop glances intel-gpu-tools nvtop lm-sensors psensor gnome-system-monitor xfce4-sensors-plugin
sensors-detect --auto || true

echo "==== 設定 chrony 關機 timeout ===="
mkdir -p /etc/systemd/system/chrony.service.d
cat << EOF > /etc/systemd/system/chrony.service.d/override.conf
[Service]
TimeoutStopSec=10s
EOF
systemctl daemon-reexec

echo "==== 安裝 flatpak ===="
apt install -y flatpak
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

echo "==== 設定預設啟動目標 ===="
systemctl set-default graphical.target

echo "==== 設定 vim 為預設編輯器 ===="
update-alternatives --set editor /usr/bin/vim.basic

echo "==== 更新 initramfs 與 grub ===="
sed -i 's/^MODULES=.*/MODULES=dep/' /etc/initramfs-tools/initramfs.conf
sed -i 's/^COMPRESS=.*/COMPRESS=xz/' /etc/initramfs-tools/initramfs.conf
update-initramfs -u
update-grub

echo ""
echo "✅ 初始設定完成！"
echo "--------------------------------------------------"
echo "1. 建立使用者：adduser liweilee"
echo "2. 加入 sudo 群組：usermod -aG sudo liweilee"
echo "3. 執行 intel_gpu_top 或 vainfo 查看硬體解碼資訊"
echo "4. 重啟系統：reboot"
echo "--------------------------------------------------"
