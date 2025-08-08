# Proxmox Desktop Setup

一鍵安裝 Proxmox VE 桌面環境（XFCE4）、中文輸入、Chrome、多媒體工具與系統監控工具。

## 🔧 安裝方式

```bash
curl -sSL https://raw.githubusercontent.com/liweileeliweilee/proxmox-desktop-setup/main/proxmox-desktop-setup.sh | bash
```

或下載後執行：

```bash
chmod +x proxmox-desktop-setup.sh
sudo ./proxmox-desktop-setup.sh
```

## 🚀 功能包含：

- 安裝 XFCE4 桌面 + LightDM
- 安裝 Google Chrome、SMPlayer、壓縮檔工具
- 安裝中文字型、Fcitx 5 新酷音輸入法
- 顯示語系設為繁體中文（zh_TW.UTF-8）
- 預設開機進入 GUI 模式
- 環境變數自動啟用 Fcitx5
- GPU 工具與溫度監控

## ❌ 移除方法

```bash
chmod +x uninstall-proxmox-desktop.sh
sudo ./uninstall-proxmox-desktop.sh
```
