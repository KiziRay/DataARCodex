# 壓縮檔密碼解鎖工具（Rust）

完全使用 Rust 重寫，不含 Python 依賴。

## 主要功能
- 針對 `ZIP/RAR/7z` 進行密碼解鎖（透過 `7z` 驗證）
- 字典攻擊
- Mask 暴力破解（`?d ?l ?u ?s ?a`）
- 多執行緒運行

## 系統需求
- Windows 10/11 x64
- 已安裝 7-Zip，且 `7z.exe` 在 PATH
- 本機建置時需 Rust toolchain

## 建置
```powershell
cargo build --release
```

輸出：
`target\release\password_recovery_rust.exe`

## 使用方式
字典攻擊：
```powershell
password_recovery_rust.exe recover --archive C:\tmp\a.zip --dict C:\tmp\rockyou.txt --threads 8
```

Mask 暴力破解：
```powershell
password_recovery_rust.exe recover --archive C:\tmp\a.7z --mask ?d?d?d?d --threads 8
```

## 一鍵啟動安裝 GUI（`irm | iex`）
```powershell
irm https://raw.githubusercontent.com/KiziRay/DataARCodex/main/install.ps1 | iex
```

此指令會開啟現代化繁體中文 GUI，主要用於安裝與啟動壓縮密碼解鎖工具。
每次執行此指令都會彈出 GUI 視窗。

## 發佈打包（GitHub Actions）
- 觸發條件：推送 tag `v*`（例如 `v2.0.1`）
- 產物檔名：`password_recovery_rust-windows-x64.zip`
- 內容：
  - `password_recovery_rust.exe`
  - `run.ps1`
  - `uninstall.ps1`
