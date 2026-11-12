#!/bin/bash
# proxmox-desktop-setup.sh
# Root 專用：Proxmox 桌面環境系統級基礎配置
# 作者：liweilee
#
# 可重複執行（idempotent）：日後要增減套件、Flatpak 應用或調整系統設定，
# 直接修改本腳本後再跑一次即可，不會重複寫入設定。
#   - 覆寫型設定（sysctl、chrony drop-in、skel 模板）：每次覆寫成相同內容
#   - 附加型設定（apt 來源、modprobe、initramfs modules）：已存在就不再寫入
#   - apt 套件與 Flatpak 應用：已安裝的自動略過
# 只想套用設定、不想等系統更新時：SKIP_UPGRADE=1 ./proxmox-desktop-setup.sh
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "❌ 請用 root 執行本腳本" >&2
    exit 1
fi

# === 小工具 ===
# 只有檔案裡還沒有「完全相同的整行」時才附加，重複執行不會重複寫入
ensure_line() {     # ensure_line "<整行內容>" <檔案>
    local line="$1" file="$2"
    touch "$file"
    if ! grep -qxF -- "$line" "$file"; then
        # shellcheck disable=SC1003  # '$a\' 是 sed 的「補檔尾換行」慣用寫法
        sed -i -e '$a\' "$file"     # 確保檔尾有換行，避免新行黏在上一行後面
        printf '%s\n' "$line" >> "$file"
    fi
}

echo "==== 更新系統來源 ===="
# 任何 apt 來源檔裡已經有（未被註解的）pve-no-subscription 就不再新增
if ! grep -rEqs '^[[:space:]]*(deb[[:space:]].*|Components:.*)pve-no-subscription' \
        /etc/apt/sources.list /etc/apt/sources.list.d/; then
    ensure_line "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" /etc/apt/sources.list
fi
sed -i 's|ftp\.tw\.debian\.org|deb.debian.org|g' /etc/apt/sources.list
sed -i 's/^deb /#deb /' /etc/apt/sources.list.d/pve-enterprise.list 2>/dev/null || true
sed -i 's/^deb /#deb /' /etc/apt/sources.list.d/ceph.list 2>/dev/null || true

echo "==== 執行系統更新 ===="
apt update
if [[ "${SKIP_UPGRADE:-0}" == "1" ]]; then
    echo "（SKIP_UPGRADE=1：略過 full-upgrade 與 autoremove）"
else
    apt full-upgrade -y
    apt autoremove -y
fi

echo "==== 安裝桌面環境 (XFCE + LightDM) ===="
apt install -y xfce4 lightdm xfce4-terminal thunar-archive-plugin

echo "==== 安裝硬體解碼核心驅動與工具 ===="
# 使用 meta-package 簡化安裝，它會自動拉取所有需要的驅動
apt install -y va-driver-all vainfo
# 標記元套件和工具為手動安裝，防止被 autoremove 誤刪
apt-mark manual va-driver-all vainfo mesa-va-drivers mesa-vulkan-drivers

echo "==== 驗證硬體解碼驅動 ===="
if vainfo_out=$(vainfo 2>&1); then
    echo "✅ vainfo 驗證通過，硬體解碼驅動已就緒。"
    grep -E "VAProfileH264|VAProfileHEVC|VAProfileVP9" <<<"$vainfo_out" | head -5 || true
else
    echo "⚠️  警告：vainfo 執行失敗，VA-API 驅動可能未正確安裝。"
fi

echo "==== 安裝DKMS/r8125-dkms/kernel headers ===="
apt install -y dkms r8125-dkms proxmox-default-headers
# 讓DKMS自動編譯並安裝所有(包含r8125)
dkms autoinstall
# 確認已經加入 DKMS
dkms status

# 阻止手動用modprobe載入r8169
ensure_line "alias r8169 off" /etc/modprobe.d/dkms.conf

# 不全域封鎖 r8169，而是透過 initramfs 指定兩個驅動同時存在，並讓 RTL8125 優先使用 r8125
ensure_line "r8125" /etc/initramfs-tools/modules
ensure_line "r8169" /etc/initramfs-tools/modules

echo "==== 安裝通用函式庫與工具 ===="
# 基礎函式庫和工具
apt install -y fonts-liberation libu2f-udev xdg-utils gdebi
# 編輯器
apt install -y vim vim-gtk3 zim
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
# Flatpak 應用清單：下面「安裝」與「權限覆寫」都用這一份，增減只要改這裡。
# 暫時不要的應用，在該行前面加 # 即可（註解寫在陣列裡是安全的）。
FLATPAK_APPS=(
    org.mozilla.firefox          # Firefox 瀏覽器
    info.smplayer.SMPlayer       # SMPlayer 播放器
    org.videolan.VLC             # VLC 播放器
    fr.handbrake.ghb             # HandBrake：把 iso 轉成 mp4
    com.simplenote.Simplenote    # Simplenote 短期筆記
    # net.cozic.joplin_desktop   # Joplin 長期筆記知識庫
    md.obsidian.Obsidian         # Obsidian 長期筆記知識庫
    io.mpv.Mpv                   # mpv 播放器
)
# 關鍵媒體運行時（增強編解碼器支援）
FLATPAK_RUNTIMES=(
    org.freedesktop.Platform.ffmpeg-full
)

# 只安裝「還沒裝」的項目，所以重複執行不會重複下載
installed_flatpaks=$(flatpak list --system --all --columns=application 2>/dev/null || true)
to_install=()
for ref in "${FLATPAK_APPS[@]}" "${FLATPAK_RUNTIMES[@]}"; do
    grep -qxF -- "$ref" <<<"$installed_flatpaks" || to_install+=("$ref")
done
if ((${#to_install[@]} > 0)); then
    flatpak install -y --system flathub "${to_install[@]}"
else
    echo "Flatpak 應用與運行時皆已安裝，略過"
fi

echo "==== 為所有使用者配置 Flatpak 應用權限 (系統級覆寫) ===="
# 使用函數來簡化重複的覆寫命令（override 重複執行結果相同）
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

# 為清單中的每個應用設置硬體加速權限
for app in "${FLATPAK_APPS[@]}"; do
    set_flatpak_permissions "$app"
done

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
echo "下一步操作指引（第一次安裝時）："
echo "1. 建立日常使用者帳號: adduser <username>"
echo "2. 將其加入 sudo 群組: usermod -aG sudo <username>"
echo "3. 切換至該使用者: su - <username>"
echo "4. 執行 proxmox-desktop-setup-user.sh"
echo "   （xfconf 的 DPI/字型設定需在桌面 session 內執行；在 tty 執行會自動略過，登入桌面後再跑一次即可）"
echo "5. 重新啟動系統以套用所有變更: reboot"
echo "=================================================="
echo "日後要調整：修改本腳本後直接重跑即可（可重複執行）。"
echo "只想套用設定、不想等系統更新：SKIP_UPGRADE=1 $0"
echo "=================================================="
echo "⭐ 本腳本已完成之系統級配置摘要："
echo "   - 硬體解碼驅動 (VA-API) 安裝與驗證"
echo "   - Flatpak 環境與應用（清單見 FLATPAK_APPS）安裝"
echo "   - 系統級 Flatpak 權限覆寫 (硬體加速)"
echo "   - 核心權限 (user namespaces) 開啟"
echo "   - 輸入法框架 (Fcitx5) 安裝與新使用者模板"
echo "   - 各類常用系統工具與影音基礎套件"
echo "=================================================="

