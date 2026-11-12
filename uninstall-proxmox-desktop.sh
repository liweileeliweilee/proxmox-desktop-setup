#!/bin/bash
set -e

echo "🔧 正在移除Flatpak 1.應用程式、2.遠端庫、3.相關套件 ..."
echo "🔧 移除Flatpak(1/3): 移除所有 Flatpak 應用程式（系統及使用者）..."
# 列出所有系統層級的應用程式，並移除
sudo flatpak list --app --columns=application | xargs sudo flatpak uninstall -y
# 列出所有使用者層級的應用程式，並移除
flatpak list --user --app --columns=application | xargs flatpak uninstall --user -y

echo "🔧 移除Flatpak(2/3): 移除 Flatpak 遠端庫（系統及使用者）..."
# 移除所有系統層級的遠端庫
sudo flatpak remotes --system | grep -v 'Name' | awk '{print $1}' | xargs -r sudo flatpak remote-delete
# 移除所有使用者層級的遠端庫
flatpak remotes --user | grep -v 'Name' | awk '{print $1}' | xargs -r flatpak remote-delete --user

echo "🔧 移除Flatpak(3/3): 移除 Flatpak 套件本身 ..."
sudo apt remove --autoremove -y flatpak


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
