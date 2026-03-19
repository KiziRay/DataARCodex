Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Install-PasswordRecoveryRust {
    [CmdletBinding()]
    param(
        [string]$Repo = "<OWNER>/<REPO>",
        [string]$InstallPath = "$env:LOCALAPPDATA\PasswordRecoveryRust",
        [switch]$Force
    )

    if ($Repo -eq "<OWNER>/<REPO>") {
        throw "請指定 GitHub repo。範例: Install-PasswordRecoveryRust -Repo 'yourname/password-recovery-rust'"
    }

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

    Write-Host "Installed to: $InstallPath"
    Write-Host "Run: & '$launcher' recover --archive <file> --dict <wordlist>"
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        Install-PasswordRecoveryRust @PSBoundParameters
    }
    catch {
        Write-Error $_
    }
}
