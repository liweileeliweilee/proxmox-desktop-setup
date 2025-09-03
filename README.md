# Proxmox Desktop Setup

一鍵安裝 Proxmox VE 桌面環境（XFCE4）、中文輸入、Chrome、多媒體工具與系統監控工具。

## 🔧 安裝方式
proxmox-desktop-setup.sh
```bash
curl -sSL https://raw.githubusercontent.com/liweileeliweilee/proxmox-desktop-setup/main/proxmox-desktop-setup.sh | bash
```

proxmox-desktop-setup-user.sh
```bash
curl -sSL https://raw.githubusercontent.com/liweileeliweilee/proxmox-desktop-setup/main/proxmox-desktop-setup-user.sh | bash
```

或下載後執行：

```bash
chmod +x proxmox-desktop-setup.sh
chmod +x proxmox-desktop-setup-user.sh
sudo ./proxmox-desktop-setup.sh
```

## 🚀 proxmox-desktop-setup.sh 功能包含：
- 安裝 XFCE4 桌面 + LightDM
- 安裝 Flatpak、Mozilla Firefox、Google Chrome、SMPlayer、XnViewMP、壓縮檔工具
- 安裝中文字型、Fcitx 5 新酷音輸入法
- 顯示語系設為繁體中文（zh_TW.UTF-8）
- 預設開機進入 GUI 模式
- 環境變數自動啟用 Fcitx5
- GPU 工具與溫度監控
## 🚀 proxmox-desktop-setup-user.sh 功能包含：
這個腳本旨在自動化在 Proxmox VE 伺服器上安裝圖形使用者介面（GUI）後的繁瑣設定工作。它會為單一使用者設定 HiDPI、調整字體與游標大小，並配置個人化的 Shell 環境。
功能特色：
- HiDPI 自動設定：為 XFCE 桌面環境設定正確的 DPI（每英吋點數），確保在高解析度螢幕上顯示正常。
- 字體與游標調整：統一設定字體大小和游標大小，解決顯示不一致的問題。
- 跨應用程式相容性：透過設定 /etc/environment 全局環境變數，確保所有應用程式（包括 GTK、Qt 和 Java 應用程式）都能正確縮放。
- Shell 環境客製化：自動設定 Bash 提示符號 (PS1) 和 PATH 變數，並新增常用別名。
- Flatpak 權限設定：為特定的 Flatpak 應用程式設定檔案系統權限，使其能夠存取共享目錄。smplayer/XnViewMP可以讀取smb整個gvfs目錄
- 安全且可重複執行：腳本採用冪等性設計，可以重複執行而不會產生重複或錯誤的設定條目。
前置需求
在執行此腳本前，請確保你的 Proxmox 伺服器已安裝一個基本的圖形桌面環境，例如 XFCE。


## ❌ 移除方法

```bash
chmod +x uninstall-proxmox-desktop.sh
sudo ./uninstall-proxmox-desktop.sh
```
