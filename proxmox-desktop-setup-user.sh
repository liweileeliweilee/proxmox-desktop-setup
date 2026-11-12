#!/bin/bash
# proxmox-desktop-setup-user.sh
# 一般使用者專用：使用者環境與 HiDPI 設定（請先以 root 執行 proxmox-desktop-setup.sh）
#
# 可重複執行（idempotent）：想調整縮放、別名、sudoers 等，
# 直接修改本腳本後再跑一次即可，不會重複寫入設定。
#   - 縮放只改下面的 SCALE（1 或 1.5…），DPI / 游標 / 字型大小由它推導
#   - ~/.bashrc、~/.profile、sudoers、~/.Xresources 使用「標記區塊」：重跑只會替換區塊內容
#   - 不在桌面 session 內執行（tty / ssh）時，會略過 xfconf 設定並提示，
#     登入桌面後在桌面內的終端機再跑一次即可
#   - /etc/profile.d 的環境變數（含 SCALE）要「登出再登入」才會生效
set -euo pipefail

# === 可調參數 ===
SCALE=1          # 只改這個：1 或 1.5（其他數值也可以）

if ! [[ "$SCALE" =~ ^[0-9]+(\.[0-9]+)?$ ]] || ! awk -v s="$SCALE" 'BEGIN{exit !(s > 0)}'; then
    echo "❌ SCALE 必須是大於 0 的數字（例如 1 或 1.5），目前是：$SCALE" >&2
    exit 1
fi

# 其餘數值由 SCALE 推導（基準：DPI 96 / 游標 32 / 字型 10；SCALE=1.5 → 144 / 48 / 15）
DPI=$(awk -v s="$SCALE" 'BEGIN{printf "%d", 96*s+0.5}')
CURSOR_SIZE=$(awk -v s="$SCALE" 'BEGIN{printf "%d", 32*s+0.5}')
FONT_SIZE=$(awk -v s="$SCALE" 'BEGIN{printf "%d", 10*s+0.5}')

# GDK_SCALE 只接受整數，這裡無條件捨去（1.5 → 1，2 維持 2）
GDK_INT_SCALE=$(awk -v s="$SCALE" 'BEGIN{printf "%d", (s < 1 ? 1 : s)}')

# === 前置檢查 ===
if [[ $EUID -eq 0 ]]; then
    echo "❌ 請用一般使用者執行（不要用 root）；root 請改執行 proxmox-desktop-setup.sh" >&2
    exit 1
fi
if ! command -v flatpak >/dev/null 2>&1; then
    echo "❌ 找不到 flatpak，請先以 root 執行 proxmox-desktop-setup.sh" >&2
    exit 1
fi

# === 小工具 ===
WARNINGS=()
warn() {
    echo "⚠️  $*" >&2
    WARNINGS+=("$*")
}

# 以「標記區塊」管理設定檔內容：重跑時只替換區塊，不會重複附加
write_block() {     # write_block <檔案> <START標記> <END標記> <內容>
    local file="$1" start="$2" end="$3" content="$4"
    touch "$file"
    if grep -qxF -- "$start" "$file"; then
        if ! grep -qxF -- "$end" "$file"; then
            echo "❌ $file 有「$start」但找不到「$end」，為避免誤刪內容已中止，請手動檢查" >&2
            return 1
        fi
        sed -i "/^${start}\$/,/^${end}\$/d" "$file"
    fi
    # shellcheck disable=SC1003  # '$a\' 是 sed 的「補檔尾換行」慣用寫法
    sed -i -e '$a\' "$file"     # 確保檔尾有換行，避免標記黏在上一行後面
    printf '%s\n%s\n%s\n' "$start" "$content" "$end" >> "$file"
}

# xfconf：--create 讓「屬性不存在 / 尚未設定值」時也能寫入，已存在則直接覆寫
xf_set() {          # xf_set <屬性> <型別> <值>
    xfconf-query -c xsettings -p "$1" --create -t "$2" -s "$3"
}

# 保留現有字型名稱，只換大小；讀不到現有字型時才用預設名稱
xf_set_font_size() {    # xf_set_font_size <屬性> <預設字型名> <大小>
    local prop="$1" fallback="$2" size="$3" cur name
    cur=$(xfconf-query -c xsettings -p "$prop" 2>/dev/null || true)
    name=$(sed -E 's/[[:space:]]+[0-9]+(\.[0-9]+)?$//' <<<"$cur")
    xf_set "$prop" string "${name:-$fallback} $size"
}

# === 腳本邏輯開始 ===
echo "==== 1. 設定使用者 Xresources (字型 DPI + 游標大小) ===="
mkdir -p "$HOME/.Xresources.d"
cat > "$HOME/.Xresources.d/hidpi" <<EOF
Xft.dpi: $DPI
Xcursor.size: $CURSOR_SIZE
Xcursor.theme: Adwaita
EOF
xrdb -merge "$HOME/.Xresources.d/hidpi" || true

# 確保 ~/.Xresources 主檔案會 include 進來（重開機後傳統 X11 軟體才會吃到）
write_block "$HOME/.Xresources" "# START_PVE_XRES" "# END_PVE_XRES" '#include ".Xresources.d/hidpi"'

echo "==== 2. 設定 XFCE 游標主題 ===="
mkdir -p "$HOME/.icons/default"
cat > "$HOME/.icons/default/index.theme" <<EOF
[Icon Theme]
Inherits=Adwaita
EOF

echo "==== 3. 設定 XFCE 核心參數 (xfconf-query) ===="
if xfconf-query -c xsettings -l >/dev/null 2>&1; then
    # 一般字體與等寬字體：保留字型名稱，只換大小
    xf_set_font_size /Gtk/FontName "Sans" "$FONT_SIZE"
    xf_set_font_size /Gtk/MonospaceFontName "Monospace" "$FONT_SIZE"

    # 其他核心參數
    xf_set /Xft/DPI int "$DPI"
    xf_set /Gtk/CursorThemeSize int "$CURSOR_SIZE"
    xf_set /Gtk/CursorThemeName string "Adwaita"

    # 視窗標題列字型（xfwm4 獨立控制）
    CUR_WM_FONT=$(xfconf-query -c xfwm4 -p /general/title_font 2>/dev/null || true)
    WM_FONT_NAME=$(sed -E 's/[[:space:]]+[0-9]+(\.[0-9]+)?$//' <<<"$CUR_WM_FONT")
    xfconf-query -c xfwm4 -p /general/title_font --create -t string -s "${WM_FONT_NAME:-Sans Bold} $FONT_SIZE"
else
    warn "偵測不到 XFCE 桌面 session（沒有 DISPLAY / D-Bus），已略過 xfconf 設定；請登入桌面後，在桌面內的終端機再執行一次本腳本"
fi

echo "==== 4. 設定 Bash 和 Profile (PS1、PATH、Aliases) ===="
# 標記開始和結束，重複執行時會找到並替換舊區塊
START_MARKER="# START_PVE_SETUP"
END_MARKER="# END_PVE_SETUP"

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
write_block "$HOME/.bashrc" "$START_MARKER" "$END_MARKER" "$BASHRC_CONTENT"

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
write_block "$HOME/.profile" "$START_MARKER" "$END_MARKER" "$PROFILE_CONTENT"

echo "==== 5. 設定 Flatpak 應用程式權限 ===="
GVFS_DIR="/run/user/$(id -u)/gvfs"
flatpak override --user --filesystem="$GVFS_DIR" info.smplayer.SMPlayer
flatpak override --user --filesystem="$GVFS_DIR" com.xnview.XnViewMP

# mpv 沙盒權限突破 (允許存取本機與 GVFS 網路磁碟)
flatpak override --user --filesystem=host io.mpv.Mpv
flatpak override --user --filesystem="$GVFS_DIR" io.mpv.Mpv

echo "==== 5.1 建立 mpv Flatpak 設定檔軟連結 ===="
MPV_SRC="$HOME/.config/mpv"
MPV_DST="$HOME/.var/app/io.mpv.Mpv/config/mpv"
mkdir -p "$(dirname "$MPV_DST")"
if [[ -L "$MPV_DST" ]]; then
    # -n：目的地已是「指向目錄的連結」時，取代連結本身，
    # 否則 ln 會把它當目錄，在 ~/.config/mpv/ 裡面再建一條指回自己的連結
    ln -sfn "$MPV_SRC" "$MPV_DST"
elif [[ ! -e "$MPV_DST" ]]; then
    ln -s "$MPV_SRC" "$MPV_DST"
elif rmdir "$MPV_DST" 2>/dev/null; then
    # 空的實體目錄（例如 mpv 第一次啟動時自己建的）→ 換成連結
    ln -s "$MPV_SRC" "$MPV_DST"
else
    warn "$MPV_DST 已存在且不是空目錄或連結，略過建立 mpv 設定連結（請手動處理）"
fi

echo "==== 6. 設定全局 HiDPI 環境變數 (/etc/profile.d/99-custom-env.sh) ===="
sudo tee /etc/profile.d/99-custom-env.sh > /dev/null <<EOF
export GTK_IM_MODULE=fcitx5
export QT_IM_MODULE=fcitx5
export XMODIFIERS=@im=fcitx5
export LANG=zh_TW.UTF-8

# GDK_SCALE 只接受整數
export GDK_SCALE=$GDK_INT_SCALE
export QT_SCALE_FACTOR=$SCALE
export _JAVA_OPTIONS='-Dsun.java2d.uiScale=$SCALE'
export XFT_DPI=$DPI
export XCURSOR_SIZE=$CURSOR_SIZE
EOF
sudo chmod 755 /etc/profile.d/99-custom-env.sh

echo "==== 7. 設定 sudoers 免密碼執行特定命令（使用標記區塊）===="
CURRENT_USER=$(whoami)
SUDOERS_FILE="/etc/sudoers.d/mystartup"
SUDOERS_START="# START_PVE_SUDOERS"
SUDOERS_END="# END_PVE_SUDOERS"

# 在暫存檔上組好內容、通過語法檢查後才寫入，避免弄壞 sudoers
TEMP_FILE=$(mktemp)
trap 'rm -f "$TEMP_FILE"' EXIT

# 讀取現有內容（檔案不存在則為空）；重導向的目標是自己的暫存檔，只有讀取需要 sudo
# shellcheck disable=SC2024
sudo cat "$SUDOERS_FILE" > "$TEMP_FILE" 2>/dev/null || true

SUDOERS_RULE=$(cat <<EOF
${CURRENT_USER} ALL=(root) NOPASSWD: \\
    /usr/bin/apt update, \\
    /usr/bin/apt full-upgrade -y, \\
    /usr/bin/apt autoremove -y, \\
    /usr/sbin/dkms autoinstall, \\
    /usr/sbin/dkms status, \\
    /usr/bin/flatpak
EOF
)
write_block "$TEMP_FILE" "$SUDOERS_START" "$SUDOERS_END" "$SUDOERS_RULE"

# 檢查語法是否正確（visudo -c -f）
if sudo visudo -c -f "$TEMP_FILE" >/dev/null 2>&1; then
    sudo install -m 440 -o root -g root "$TEMP_FILE" "$SUDOERS_FILE"
    echo "✅ sudoers 設定已更新（$SUDOERS_FILE）"
else
    warn "sudoers 語法檢查失敗，未變更任何設定！請檢查內容（$SUDOERS_FILE）"
fi

echo ""
if ((${#WARNINGS[@]} > 0)); then
    echo "⚠️  已完成，但有 ${#WARNINGS[@]} 項需要注意（見上方 ⚠️ 訊息）："
    for w in "${WARNINGS[@]}"; do
        echo "    - $w"
    done
else
    echo "✅ 所有設定已完成！"
fi
echo "    → SCALE=$SCALE, GDK_SCALE=$GDK_INT_SCALE, DPI=$DPI, Font=$FONT_SIZE, Cursor=$CURSOR_SIZE"
echo "⚠️  請登出再登入，讓 /etc/profile.d 的環境變數（含 SCALE）生效；"
echo "    只想套用 shell 設定可執行 'source ~/.bashrc && source ~/.profile'。"

