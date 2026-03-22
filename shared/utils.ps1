<#
.SYNOPSIS
    共用工具函數
.DESCRIPTION
    提供各模組可重複使用的工具函數
#>

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-FileHash256 {
    param([string]$FilePath)

    if (-not (Test-Path $FilePath)) {
        throw "檔案不存在: $FilePath"
    }

    $hash = Get-FileHash -Path $FilePath -Algorithm SHA256
    return $hash.Hash
}

function ConvertTo-PrettyJson {
    param(
        [Parameter(ValueFromPipeline)]
        $InputObject,
        [int]$Depth = 4
    )

    $InputObject | ConvertTo-Json -Depth $Depth
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [string]$LogFile = $null
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    Write-Host $logMessage

    if ($LogFile) {
        Add-Content -Path $LogFile -Value $logMessage
    }
}

function Invoke-WithRetry {
    param(
        [ScriptBlock]$ScriptBlock,
        [int]$MaxRetries = 3,
        [int]$DelaySeconds = 2
    )

    $attempt = 0
    $success = $false
    $lastError = $null

    while (-not $success -and $attempt -lt $MaxRetries) {
        $attempt++
        try {
            & $ScriptBlock
            $success = $true
        } catch {
            $lastError = $_
            if ($attempt -lt $MaxRetries) {
                Write-Warning "嘗試 $attempt 失敗，$DelaySeconds 秒後重試..."
                Start-Sleep -Seconds $DelaySeconds
            }
        }
    }

    if (-not $success) {
        throw "操作失敗，已重試 $MaxRetries 次: $($lastError.Exception.Message)"
    }
}

function Get-RandomString {
    param(
        [int]$Length = 16,
        [switch]$AlphaNumericOnly
    )

    if ($AlphaNumericOnly) {
        $chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    } else {
        $chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()"
    }

    $random = 1..$Length | ForEach-Object { Get-Random -Maximum $chars.Length }
    return -join ($random | ForEach-Object { $chars[$_] })
}
