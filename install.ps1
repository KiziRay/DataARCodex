<#
.SYNOPSIS
    Bootstrap launcher for Password Recovery Rust installer.
.DESCRIPTION
    Similar to winutil bootstrap style:
    irm https://raw.githubusercontent.com/KiziRay/DataARCodex/main/install.ps1 | iex
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repo = if ($env:PRR_REPO) { $env:PRR_REPO } else { "KiziRay/DataARCodex" }
$ref = if ($env:PRR_REF) { $env:PRR_REF } else { "main" }
$scriptPath = "installer-main.ps1"
$mainScript = "https://raw.githubusercontent.com/$repo/$ref/$scriptPath"
Invoke-RestMethod $mainScript | Invoke-Expression
