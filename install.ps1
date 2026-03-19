<#
.SYNOPSIS
    Bootstrap launcher for Password Recovery Rust installer.
.DESCRIPTION
    Similar to winutil bootstrap style:
    irm https://raw.githubusercontent.com/KiziRay/DataARCodex/main/install.ps1 | iex
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repo = "KiziRay/DataARCodex"
$scriptPath = "installer-main.ps1"

try {
    $latestTag = (Invoke-RestMethod "https://api.github.com/repos/$repo/tags")[0].name
    $releaseScript = "https://raw.githubusercontent.com/$repo/$latestTag/$scriptPath"
    Invoke-RestMethod $releaseScript | Invoke-Expression
}
catch {
    $mainScript = "https://raw.githubusercontent.com/$repo/main/$scriptPath"
    Invoke-RestMethod $mainScript | Invoke-Expression
}
