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

echo "==== 安裝常用工具 ===="
apt install -y net-tools vim curl sudo gdebi

echo "==== 安裝桌面環境 XFCE + LightDM ===="
apt install -y xfce4 lightdm xfce4-terminal thunar-archive-plugin

echo "==== 安裝 Google Chrome 依賴與瀏覽器 ===="
apt install -y fonts-liberation libu2f-udev xdg-utils
wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
dpkg -i google-chrome-stable_current_amd64.deb || apt -f install -y
rm -f google-chrome-stable_current_amd64.deb

echo "==== 安裝字型與輸入法 ===="
apt install -y fonts-noto-cjk fcitx5 fcitx5-chewing fcitx5-configtool

echo "==== 設定 fcitx5 環境變數 ===="
echo 'GTK_IM_MODULE=fcitx' >> /etc/environment
echo 'QT_IM_MODULE=fcitx' >> /etc/environment
echo 'XMODIFIERS=@im=fcitx' >> /etc/environment

echo "==== 設定 fcitx5 開機自動啟動 ===="
mkdir -p ~/.config/autostart
cp /usr/share/applications/org.fcitx.Fcitx5.desktop ~/.config/autostart/

echo "==== 設定預設語言為繁體中文 ===="
echo 'LANG=zh_TW.UTF-8' >> /etc/environment

echo "==== 安裝 GTK 版本 vim 以支援剪貼簿 ===="
apt install -y vim-gtk3

echo "==== 安裝影音播放工具 ===="
apt install -y smplayer

echo "==== 安裝影像支援工具與格式 ===="
apt install -y libheif-dev

echo "==== 安裝硬體監控工具 ===="
apt install -y intel-gpu-tools intel-media-va-driver vainfo nvtop lm-sensors psensor xfce4-sensors-plugin
sensors-detect --auto || true

echo "==== 安裝Thunar browse smb目錄工具 ===="
apt install -y gvfs-backends
apt install -y smbclient samba
apt install -y kio-fuse gvfs-fuse

echo "==== 設定 chrony 關機 timeout ===="
mkdir -p /etc/systemd/system/chrony.service.d
cat << EOF > /etc/systemd/system/chrony.service.d/override.conf
[Service]
TimeoutStopSec=10s
EOF
systemctl daemon-reexec

echo "==== 設定開機進入圖形介面 ===="
systemctl set-default graphical.target

echo "==== 設定 vim 為預設編輯器 ===="
update-alternatives --set editor /usr/bin/vim.basic

echo "🔧 修改 /etc/initramfs-tools/initramfs.conf ..."
sudo sed -i 's/^MODULES=.*/MODULES=dep/' /etc/initramfs-tools/initramfs.conf
sudo sed -i 's/^COMPRESS=.*/COMPRESS=xz/' /etc/initramfs-tools/initramfs.conf

echo "📦 更新 initramfs ..."
sudo update-initramfs -u
sudo update-grub

echo "🔧 修改 /root/.bashrc ..."
tee -a /root/.bashrc <<'EOF'
# Added by liweilee
# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi
export PS1="\[\e[41m\]\t\[\e[m\][\u@\h:\w]$ "
#export PS1="\[\e[0;30;47m\]\t\[\e[m\][\u@\h:\w]$ "
alias chrome-gtk4='env GTK_IM_MODULE=fcitx5 QT_IM_MODULE=fcitx5 XMODIFIERS="@im=fcitx5" google-chrome --gtk-version=4 2>/dev/null &'
EOF

echo "🔧 修改 /root/.profile ..."
tee -a /root/.profile <<'EOF'
# Added by liweilee
export PS1="\[\e[41m\]\t\[\e[m\][\u@\h:\w]$ "
#export PS1="\[\e[0;30;47m\]\t\[\e[m\][\u@\h:\w]$ "
EOF

echo ""
echo "✅ 初始設定完成！接下來請手動執行以下步驟："
echo "--------------------------------------------------"
echo "1. 建立使用者：         adduser liweilee"
echo "2. 加入 sudo 群組：     usermod -aG sudo liweilee"
echo "3. 編輯 sudoers（可選）：visudo"
echo "4. 執行 intel_gpu_top 或 psensor 查看資訊"
echo "--------------------------------------------------"
