# 壓縮檔密碼解鎖工具（Rust）

完全使用 Rust 重寫，不含 Python 依賴。

## 主要功能
- 壓縮檔密碼解鎖流程（ZIP/RAR/7z）
- `extract-hash`：使用 John the Ripper 工具鏈提取雜湊
- `john-crack`：使用 John the Ripper 進行字典破解
- `hashcat-crack`：使用 Hashcat 進行 GPU 破解（mask / 字典）
- `recover`：內建 7z 驗證模式（快速本機字典/掩碼測試）

## 系統需求
- Windows 10/11 x64
- `7z.exe`（PATH）
- John the Ripper（`zip2john`/`rar2john`/`7z2john.pl`/`john`）
- Hashcat（`hashcat`）
- 若處理 `.7z`：需安裝 Perl（如 Strawberry Perl）

## 核心流程（你指定的邏輯）
1. 先提取 hash
2. 用 John 或 Hashcat 破解
3. 必要時換更大型字典（如 SecLists）

## 指令
### 1) 提取 hash
```powershell
password_recovery_rust.exe extract-hash --archive C:\target\secret.rar --out C:\target\hash.txt --john-dir C:\tools\john\run
```

7z 範例（含 Perl）：
```powershell
password_recovery_rust.exe extract-hash --archive C:\target\secret.7z --out C:\target\hash.txt --john-dir C:\tools\john\run --perl C:\Strawberry\perl\bin\perl.exe
```

### 2) John 字典破解
```powershell
password_recovery_rust.exe john-crack --hash-file C:\target\hash.txt --wordlist C:\wordlists\rockyou.txt --john C:\tools\john\run\john.exe
```

### 3) Hashcat GPU 破解（例：RAR5 mode=13000 + mask）
```powershell
password_recovery_rust.exe hashcat-crack --hash-file C:\target\hash.txt --mode 13000 --attack 3 --mask ?d?d?d?d?d?d?d?d --hashcat C:\tools\hashcat\hashcat.exe
```

### 4) 內建 recover（非 John/Hashcat）
```powershell
password_recovery_rust.exe recover --archive C:\target\secret.zip --dict C:\wordlists\rockyou.txt --threads 8
```

## 一鍵開啟安裝 GUI
```powershell
irm https://raw.githubusercontent.com/KiziRay/DataARCodex/main/install.ps1 | iex
```

若要開啟特定分支或 tag（例如尚未合併到 `main` 的版本）：
```powershell
$env:PRR_REF = "your-branch-or-tag"
irm https://raw.githubusercontent.com/KiziRay/DataARCodex/your-branch-or-tag/install.ps1 | iex
```

## Tauri 桌面 GUI（B 路線）
- 位置：`src-tauri/`（Rust backend）+ `ui/`（前端）
- 前端採繁體中文現代化介面，對應：
  1. 提取 Hash（John 工具鏈）
  2. John 字典破解
  3. Hashcat GPU 破解
  4. 內建快速模式

啟動（需先安裝 Tauri 相關工具）：
```powershell
cd src-tauri
cargo tauri dev
```

## 發佈打包（GitHub Actions）
- 觸發：push tag `v*`
- 產物：`password_recovery_rust-windows-x64.zip`
