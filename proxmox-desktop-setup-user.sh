#!/bin/bash
# proxmox-desktop-setup-user.sh
# 最終版：最簡潔、最正確、同時設定 DPI 與使用者環境

set -e

# === 可調參數 ===
DPI=144
SCALE=1.5
CURSOR_SIZE=48
FONT_SIZE=15

# === 腳本邏輯開始 ===
echo "==== 1. 設定使用者 Xresources (字型 DPI + 游標大小) ===="
mkdir -p "$HOME"/.Xresources.d
cat > "$HOME"/.Xresources.d/hidpi <<EOF
Xft.dpi: $DPI
Xcursor.size: $CURSOR_SIZE
Xcursor.theme: Adwaita
EOF
xrdb -merge "$HOME"/.Xresources.d/hidpi || true

echo "==== 2. 設定 XFCE 游標主題 ===="
mkdir -p "$HOME"/.icons/default
cat > "$HOME"/.icons/default/index.theme <<EOF
[Icon Theme]
Inherits=Adwaita
EOF

echo "==== 3. 設定 XFCE 核心參數 (xfconf-query) ===="
# 取得並設定一般字體大小
CURRENT_FONT=$(xfconf-query -c xsettings -p /Gtk/FontName)
FONT_NAME=$(echo "$CURRENT_FONT" | sed -E 's/ [0-9]+$//')
xfconf-query -c xsettings -p /Gtk/FontName -s "$FONT_NAME $FONT_SIZE"

# 取得並設定等寬字體大小
CURRENT_MONO_FONT=$(xfconf-query -c xsettings -p /Gtk/MonospaceFontName)
MONO_FONT_NAME=$(echo "$CURRENT_MONO_FONT" | sed -E 's/ [0-9]+$//')
xfconf-query -c xsettings -p /Gtk/MonospaceFontName -s "$MONO_FONT_NAME $FONT_SIZE"

# 設定其他核心參數
xfconf-query -c xsettings -p /Xft/DPI -s 144
xfconf-query -c xsettings -p /Gtk/CursorThemeSize -s $CURSOR_SIZE
xfconf-query -c xsettings -p /Gtk/CursorThemeName -s "Adwaita"

echo "==== 4. 設定 Bash 和 Profile (PS1、PATH、Aliases) ===="
# 標記開始和結束，以便重複執行時可以找到並替換
START_MARKER="# START_PVE_SETUP"
END_MARKER="# END_PVE_SETUP"

# 函數：檢查並刪除舊的區塊
clean_and_write() {
    local file="$1"
    local content="$2"

    # 如果舊的標記存在，就刪除整個區塊
    sed -i "/^${START_MARKER}/, /^${END_MARKER}/d" "$file" 2>/dev/null || true

    # 新增新的設定區塊
    tee -a "$file" <<EOF
${START_MARKER}
${content}
${END_MARKER}
EOF
}

# 設定 .bashrc 內容
BASHRC_CONTENT=$(cat <<'EOF_BASHRC'
# Added by liweilee 20250820
# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi

# Determine PS1 based on user type (root vs. regular)
if [[ $EUID -eq 0 ]]; then
    # Settings for root user (red background)
    export PS1="\[\e[41m\]\t\[\e[m\][\u@\h:\w]$ "
else
    # Settings for regular user (white background with black text)
    export PS1="\[\e[0;30;47m\]\t\[\e[m\][\u@\h:\w]$ "
fi

# 其他別名和設定
alias chrome-gtk4='env GTK_IM_MODULE=fcitx5 QT_IM_MODULE=fcitx5 XMODIFIERS="@im=fcitx5" google-chrome --gtk-version=4 2>/dev/null &'
alias mpv='flatpak run io.mpv.Mpv'
EOF_BASHRC
)
clean_and_write "$HOME/.bashrc" "$BASHRC_CONTENT"

# 設定 .profile 內容
PROFILE_CONTENT=$(cat <<'EOF_PROFILE'
# Added by liweilee 20250820
if [[ $EUID -eq 0 ]]; then
    export PS1="\[\e[41m\]\t\[\e[m\][\u@\h:\w]$ "
else
    export PS1="\[\e[0;30;47m\]\t\[\e[m\][\u@\h:\w]$ "
fi
EOF_PROFILE
)
clean_and_write "$HOME/.profile" "$PROFILE_CONTENT"

echo "==== 5. 設定 Flatpak 應用程式權限 ===="
flatpak override --user --filesystem=/run/user/$(id -u)/gvfs info.smplayer.SMPlayer
flatpak override --user --filesystem=/run/user/$(id -u)/gvfs com.xnview.XnViewMP

# mpv 沙盒權限突破 (允許存取本機與 GVFS 網路磁碟)
flatpak override --user --filesystem=host io.mpv.Mpv
flatpak override --user --filesystem=/run/user/$(id -u)/gvfs io.mpv.Mpv

echo "==== 5.1 建立 mpv Flatpak 設定檔軟連結 ===="
mkdir -p "$HOME/.var/app/io.mpv.Mpv/config"
ln -sf "$HOME/.config/mpv" "$HOME/.var/app/io.mpv.Mpv/config/mpv"

echo "==== 6. 設定全局 HiDPI 環境變數 (/etc/profile.d/99-custom-env.sh) ===="
sudo tee /etc/profile.d/99-custom-env.sh > /dev/null <<EOF
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
export LANG=zh_TW.UTF-8

export GDK_SCALE=$SCALE
export QT_SCALE_FACTOR=$SCALE
export _JAVA_OPTIONS='-Dsun.java2d.uiScale='$SCALE
export XFT_DPI=$DPI
export XCURSOR_SIZE=$CURSOR_SIZE
EOF
sudo chmod 755 /etc/profile.d/99-custom-env.sh

echo "==== 7. 設定 sudoers 免密碼執行特定命令（使用標記區塊）===="
CURRENT_USER=$(whoami)
SUDOERS_FILE="/etc/sudoers.d/mystartup"
START_MARKER="# START_PVE_SUDOERS"
END_MARKER="# END_PVE_SUDOERS"

# 暫存檔案（避免直接編輯系統檔案時出錯）
TEMP_FILE=$(mktemp)

# 若檔案不存在則建立空檔案
sudo touch "$SUDOERS_FILE"
sudo chmod 440 "$SUDOERS_FILE"

# 讀取現有內容（若檔案不存在則為空）
sudo cat "$SUDOERS_FILE" > "$TEMP_FILE" 2>/dev/null || true

# 刪除舊的標記區塊（如果存在）
sed -i "/^${START_MARKER}/, /^${END_MARKER}/d" "$TEMP_FILE"

# 準備要新增的區塊
NEW_BLOCK=$(cat <<EOF
${START_MARKER}
${CURRENT_USER} ALL=(root) NOPASSWD: \\
    /usr/bin/apt update, \\
    /usr/bin/apt full-upgrade -y, \\
    /usr/bin/apt autoremove -y, \\
    /usr/sbin/dkms autoinstall, \\
    /usr/sbin/dkms status
${END_MARKER}
EOF
)

# 將新區塊附加到暫存檔案末尾
echo "$NEW_BLOCK" >> "$TEMP_FILE"

# 檢查語法是否正確（visudo -c -f）
if sudo visudo -c -f "$TEMP_FILE" >/dev/null 2>&1; then
    # 語法正確，寫回目標檔案
    sudo tee "$SUDOERS_FILE" < "$TEMP_FILE" >/dev/null
    echo "✅ sudoers 設定已更新（$SUDOERS_FILE）"
else
    echo "❌ sudoers 語法檢查失敗，未變更任何設定！請檢查內容。"
    # 可選擇刪除暫存檔案
fi
rm -f "$TEMP_FILE"



echo ""
echo "✅ 所有設定已完成！"
echo "    → DPI=$DPI, Scale=$SCALE, Font=$FONT_SIZE, Cursor=$CURSOR_SIZE"
echo "⚠️  請重新登入或執行 'source ~/.bashrc && source ~/.profile' 來套用設定。"
