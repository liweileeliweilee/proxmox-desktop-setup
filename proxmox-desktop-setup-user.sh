#!/bin/bash

# 這個腳本必須以目標使用者身份執行，或是以 root 身份模擬目標使用者。
# 例如：sudo -u <username> ./universal_ps1_setup.sh

# 確保 $HOME 環境變數存在
if [ -z "$HOME" ]; then
    echo "錯誤：無法取得 \$HOME 環境變數。"
    exit 1
fi






echo "🔧 修改 $HOME/.bashrc ..."
tee -a "$HOME/.bashrc" <<'EOF'
# Added by liweilee
# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
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
EOF





echo "🔧 修改 $HOME/.profile ..."
tee -a "$HOME/.profile" <<'EOF'
# Added by liweilee
if [[ $EUID -eq 0 ]]; then
    export PS1="\[\e[41m\]\t\[\e[m\][\u@\h:\w]$ "
else
    export PS1="\[\e[0;30;47m\]\t\[\e[m\][\u@\h:\w]$ "
fi
EOF





echo "==== 設定用flatpak裝的smplayer可以讀取smb整個gvfs目錄 ===="
flatpak override --user --filesystem=/run/user/$(id -u)/gvfs info.smplayer.SMPlayer

echo "==== 設定用flatpak裝的XnViewMP可以讀取smb整個gvfs目錄 ===="
flatpak override --user --filesystem=/run/user/$(id -u)/gvfs com.xnview.XnViewMP

echo "腳本執行完畢。"
echo "請重新登入或執行 'source ~/.bashrc && source ~/.profile' 來套用設定。"

