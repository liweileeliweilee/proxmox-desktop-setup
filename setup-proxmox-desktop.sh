#!/bin/bash
set -e

echo "🔧 設定 pve-no-subscription 套件來源..."
echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" | sudo tee /etc/apt/sources.list.d/pve-no-sub.list

echo "🧹 註解掉 enterprise 與 ceph 套件來源..."
for file in /etc/apt/sources.list.d/pve-enterprise.list /etc/apt/sources.list.d/ceph.list; do
    if [ -f "$file" ]; then
        sudo sed -i 's/^\([^#].*\)$/# /' "$file"
    fi
done

echo "📦 系統更新中..."
sudo apt update -y && sudo apt dist-upgrade -y

echo "🛠 安裝基本工具..."
sudo apt install -y net-tools vim curl sudo gdebi

echo "👤 新增使用者 liweilee 並加入 sudo 群組..."
sudo adduser liweilee
sudo usermod -aG sudo liweilee

echo "🖥 安裝 XFCE4 與登入管理器 lightdm..."
sudo apt install -y xfce4 lightdm

echo "🌐 安裝 Chrome 所需的相依套件..."
sudo apt install -y fonts-liberation libu2f-udev xdg-utils

echo "🌐 下載並安裝 Google Chrome..."
wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo dpkg -i google-chrome-stable_current_amd64.deb || sudo apt --fix-broken install -y
rm google-chrome-stable_current_amd64.deb

echo "🖥 安裝 XFCE 終端機..."
sudo apt install -y xfce4-terminal

echo "🌏 安裝中文字型顯示..."
sudo apt install -y fonts-noto-cjk

echo "⌨️ 安裝 Fcitx 5 新酷音輸入法..."
sudo apt install -y fcitx5 fcitx5-chewing fcitx5-configtool

echo "🌐 設定 Fcitx5 環境變數..."
sudo tee -a /etc/environment > /dev/null <<EOF
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
INPUT_METHOD=fcitx
DefaultIMModule=fcitx
EOF

echo "📋 安裝 vim-gtk3 支援 clipboard 複製貼上..."
sudo apt install -y vim-gtk3

echo "🎞 安裝 SMPlayer..."
sudo apt install -y smplayer

echo "🗃 安裝壓縮檔整合支援..."
sudo apt install -y thunar-archive-plugin

echo "🖼 安裝 HEIF/HEIC 支援函式庫..."
sudo apt install -y libheif-dev

echo "📊 安裝 GPU 工具..."
sudo apt install -y intel-gpu-tools intel-media-va-driver vainfo nvtop

echo "🕰 設定 chrony 關機 timeout..."
sudo mkdir -p /etc/systemd/system/chrony.service.d
echo -e "[Service]\nTimeoutStopSec=10s" | sudo tee /etc/systemd/system/chrony.service.d/timeout.conf
sudo systemctl daemon-reexec

echo "🌡 安裝硬體感測與溫度圖形工具..."
sudo apt install -y lm-sensors psensor xfce4-sensors-plugin

echo "🌐 設定系統語系為繁體中文..."
sudo sed -i 's/^# *zh_TW.UTF-8/zh_TW.UTF-8/' /etc/locale.gen
sudo locale-gen
sudo update-locale LANG=zh_TW.UTF-8
sudo localectl set-locale LANG=zh_TW.UTF-8

echo "🖥 設定預設開機進入 GUI 模式..."
sudo systemctl set-default graphical.target

echo ""
echo "🔧 接下來是手動操作步驟，請逐一執行："
echo ""
echo "📝 1. 設定預設編輯器為 vim（選擇 vim）:"
echo "    sudo update-alternatives --config editor"
echo ""
echo "🔒 2. (選用) 編輯 sudo 設定（可跳過）："
echo "    sudo visudo"
echo ""
echo "📊 3. 執行感測器偵測（按 Enter 掃描硬體）："
echo "    sudo sensors-detect"
echo ""
echo "💻 4. 檢視 GPU 狀態（可 Ctrl+C 離開）："
echo "    sudo intel_gpu_top"
echo ""
echo "✅ 所有安裝與設定已完成，請重新登入以套用語系與輸入法設定。"
