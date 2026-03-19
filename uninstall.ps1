Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

param(
    [string]$InstallPath = "$env:LOCALAPPDATA\PasswordRecoveryRust"
)

if (Test-Path $InstallPath) {
    Remove-Item -Path $InstallPath -Recurse -Force
    Write-Host "Removed: $InstallPath"
} else {
    Write-Host "Not found: $InstallPath"
}
