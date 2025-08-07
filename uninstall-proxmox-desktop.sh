#!/bin/bash
set -e

echo "🔧 正在移除 Proxmox Desktop 環境套件..."

sudo apt remove --purge -y \
    xfce4 lightdm xfce4-terminal \
    smplayer thunar-archive-plugin \
    google-chrome-stable \
    fcitx5 fcitx5-chewing fcitx5-configtool \
    fonts-noto-cjk fonts-liberation \
    vim-gtk3 \
    lm-sensors psensor xfce4-sensors-plugin \
    intel-gpu-tools intel-media-va-driver vainfo nvtop \
    libheif-dev

sudo apt autoremove -y

echo "🧹 清除 Fcitx5 環境變數..."
sudo sed -i '/^GTK_IM_MODULE=fcitx/d' /etc/environment
sudo sed -i '/^QT_IM_MODULE=fcitx/d' /etc/environment
sudo sed -i '/^XMODIFIERS=@im=fcitx/d' /etc/environment
sudo sed -i '/^INPUT_METHOD=fcitx/d' /etc/environment
sudo sed -i '/^DefaultIMModule=fcitx/d' /etc/environment

echo "🗑 移除 Chrome 安裝殘留..."
sudo rm -f /etc/apt/sources.list.d/google-chrome.list*

echo "🖥 還原至文字模式開機..."
sudo systemctl set-default multi-user.target

echo "✅ Proxmox Desktop 環境已移除。"
