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

## 發佈打包（GitHub Actions）
- 觸發：push tag `v*`
- 產物：`password_recovery_rust-windows-x64.zip`
