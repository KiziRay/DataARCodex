<#
.SYNOPSIS
    Bootstrap launcher for CipherBreak.
.DESCRIPTION
    irm https://raw.githubusercontent.com/KiziRay/DataARCodex/main/install.ps1 | iex
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$repo = if ($env:PRR_REPO) { $env:PRR_REPO } else { "KiziRay/DataARCodex" }
$ref  = if ($env:PRR_REF)  { $env:PRR_REF }  else { "main" }
$url  = "https://raw.githubusercontent.com/$repo/$ref/installer-main.ps1"

$script = (Invoke-RestMethod $url).TrimStart([char]0xFEFF)
Invoke-Expression $script
