Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
# installer script version: 2

function Uninstall-PasswordRecoveryRust {
    [CmdletBinding()]
    param(
        [string]$InstallPath = "$env:LOCALAPPDATA\PasswordRecoveryRust"
    )

    if (Test-Path $InstallPath) {
        Remove-Item -Path $InstallPath -Recurse -Force
        Write-Host "Removed: $InstallPath" -ForegroundColor Yellow
    }
    else {
        Write-Host "Not installed: $InstallPath" -ForegroundColor DarkYellow
    }
}

function Install-PasswordRecoveryRust {
    [CmdletBinding()]
    param(
        [string]$Repo = "KiziRay/DataARCodex",
        [string]$InstallPath = "$env:LOCALAPPDATA\PasswordRecoveryRust",
        [switch]$Force
    )

    if (Test-Path $InstallPath) {
        if (-not $Force) {
            throw "InstallPath 已存在: $InstallPath。加上 -Force 覆蓋。"
        }
        Remove-Item -Path $InstallPath -Recurse -Force
    }

    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null

    $api = "https://api.github.com/repos/$Repo/releases/latest"
    $release = Invoke-RestMethod -Uri $api
    $asset = $release.assets | Where-Object { $_.name -match "windows" -and $_.name -match "x64" -and $_.name -match "\.zip$" } | Select-Object -First 1

    if (-not $asset) {
        throw "找不到 windows x64 zip 資產，請確認 release 檔名。"
    }

    $zipPath = Join-Path $env:TEMP "password_recovery_rust_latest.zip"
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath
    Expand-Archive -Path $zipPath -DestinationPath $InstallPath -Force
    Remove-Item $zipPath -Force

    $launcher = Join-Path $InstallPath "run.ps1"
@"
`$exe = Join-Path `$PSScriptRoot 'password_recovery_rust.exe'
if (-not (Test-Path `$exe)) { throw 'password_recovery_rust.exe not found' }
& `$exe `$args
"@ | Set-Content -Path $launcher -Encoding UTF8

    $uninstall = Join-Path $InstallPath "uninstall.ps1"
@"
Set-StrictMode -Version Latest
`$ErrorActionPreference = 'Stop'
Remove-Item -Path `"$InstallPath`" -Recurse -Force
Write-Host 'Uninstalled PasswordRecoveryRust'
"@ | Set-Content -Path $uninstall -Encoding UTF8

    Write-Host "Installed to: $InstallPath" -ForegroundColor Green
    Write-Host "Run: & '$launcher' recover --archive <file> --dict <wordlist>"
}

function Show-InstallMenu {
    [CmdletBinding()]
    param(
        [string]$DefaultRepo = "KiziRay/DataARCodex",
        [string]$InstallPath = "$env:LOCALAPPDATA\PasswordRecoveryRust"
    )

    while ($true) {
        Clear-Host
        Write-Host "============================================"
        Write-Host " Password Recovery Rust Installer"
        Write-Host "============================================"
        Write-Host "Repo: $DefaultRepo"
        Write-Host "Path: $InstallPath"
        Write-Host ""
        Write-Host "[1] Install"
        Write-Host "[2] Reinstall (Force)"
        Write-Host "[3] Uninstall"
        Write-Host "[4] Exit"
        Write-Host ""

        $choice = Read-Host "Choose (1-4)"

        switch ($choice) {
            "1" {
                try {
                    Install-PasswordRecoveryRust -Repo $DefaultRepo -InstallPath $InstallPath
                }
                catch {
                    Write-Host "Install failed: $($_.Exception.Message)" -ForegroundColor Red
                }
                Read-Host "Press Enter to continue" | Out-Null
            }
            "2" {
                try {
                    Install-PasswordRecoveryRust -Repo $DefaultRepo -InstallPath $InstallPath -Force
                }
                catch {
                    Write-Host "Reinstall failed: $($_.Exception.Message)" -ForegroundColor Red
                }
                Read-Host "Press Enter to continue" | Out-Null
            }
            "3" {
                try {
                    Uninstall-PasswordRecoveryRust -InstallPath $InstallPath
                }
                catch {
                    Write-Host "Uninstall failed: $($_.Exception.Message)" -ForegroundColor Red
                }
                Read-Host "Press Enter to continue" | Out-Null
            }
            "4" {
                break
            }
            default {
                Write-Host "Invalid option" -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        if ($PSBoundParameters.Count -gt 0) {
            Install-PasswordRecoveryRust @PSBoundParameters
        }
        else {
            Show-InstallMenu
        }
    }
    catch {
        Write-Error $_
    }
}
