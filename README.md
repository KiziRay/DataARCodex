# Password Recovery Rust (v2)

Fully rewritten in Rust. No Python.

## Features
- Supports ZIP/RAR/7z archive password verification via `7z`
- Dictionary attack
- Mask brute force (`?d ?l ?u ?s ?a`)
- Multi-threaded execution

## Requirements
- Windows 10/11 x64
- 7-Zip installed, `7z.exe` available in PATH
- Rust toolchain for local build

## Build
```powershell
cargo build --release
```

Output:
`target\release\password_recovery_rust.exe`

## Usage
Dictionary:
```powershell
password_recovery_rust.exe recover --archive C:\tmp\a.zip --dict C:\tmp\rockyou.txt --threads 8
```

Mask:
```powershell
password_recovery_rust.exe recover --archive C:\tmp\a.7z --mask ?d?d?d?d --threads 8
```

## Install by `irm | iex`
```powershell
irm https://raw.githubusercontent.com/KiziRay/DataARCodex/main/install.ps1 | iex
```
This command opens an interactive installer UI (WinUtil style).

Custom repo (optional):
```powershell
irm https://raw.githubusercontent.com/KiziRay/DataARCodex/main/install.ps1 | iex; Install-PasswordRecoveryRust -Repo "KiziRay/DataARCodex" -Force
```

## Release Packaging (GitHub Actions)
- Trigger: push tag `v*` (for example `v2.0.1`)
- Output asset: `password_recovery_rust-windows-x64.zip`
- Includes:
  - `password_recovery_rust.exe`
  - `run.ps1`
  - `uninstall.ps1`
