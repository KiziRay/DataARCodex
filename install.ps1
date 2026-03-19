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
$mainScript = "https://raw.githubusercontent.com/$repo/main/$scriptPath"
Invoke-RestMethod $mainScript | Invoke-Expression
