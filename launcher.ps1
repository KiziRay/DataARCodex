<#
.SYNOPSIS
    Community Toolkit - 模組化工具包啟動器
.DESCRIPTION
    載入並管理所有工具模組的主入口
#>

param(
    [string]$ModuleName = $null
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# 載入設定
$script:Config = Get-Content "$PSScriptRoot\config.json" -Raw | ConvertFrom-Json
$script:ModulesPath = Join-Path $PSScriptRoot $script:Config.modules_path

# 載入核心框架
. "$PSScriptRoot\core\module-loader.ps1"
. "$PSScriptRoot\core\ui-framework.ps1"

# 主函數
function Start-Toolkit {
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  $($script:Config.name) v$($script:Config.version)" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""

    # 載入所有模組
    $modules = Get-AvailableModules

    if ($modules.Count -eq 0) {
        Write-Host "⚠ 未找到任何模組" -ForegroundColor Yellow
        Write-Host "請在 modules/ 目錄中新增模組" -ForegroundColor Gray
        return
    }

    # 如果指定了模組名稱，直接啟動
    if ($ModuleName) {
        $module = $modules | Where-Object { $_.name -eq $ModuleName }
        if ($module) {
            Start-Module $module
            return
        } else {
            Write-Host "✗ 找不到模組: $ModuleName" -ForegroundColor Red
            return
        }
    }

    # 顯示模組選單
    Show-ModuleMenu $modules
}

# 顯示模組選單
function Show-ModuleMenu {
    param($Modules)

    while ($true) {
        Write-Host ""
        Write-Host "可用模組:" -ForegroundColor Green
        Write-Host ""

        for ($i = 0; $i -lt $Modules.Count; $i++) {
            $module = $Modules[$i]
            Write-Host "  [$($i + 1)] $($module.display_name)" -ForegroundColor White
            Write-Host "      $($module.description)" -ForegroundColor Gray
        }

        Write-Host ""
        Write-Host "  [0] 結束" -ForegroundColor Yellow
        Write-Host ""
        Write-Host -NoNewline "請選擇模組 (輸入編號): " -ForegroundColor Cyan

        $choice = Read-Host

        if ($choice -eq "0") {
            Write-Host "再見！" -ForegroundColor Green
            break
        }

        $index = [int]$choice - 1
        if ($index -ge 0 -and $index -lt $Modules.Count) {
            Write-Host ""
            Start-Module $Modules[$index]
            Write-Host ""
            Write-Host "按任意鍵返回主選單..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        } else {
            Write-Host "✗ 無效的選擇" -ForegroundColor Red
        }
    }
}

# 啟動
if ($MyInvocation.InvocationName -ne ".") {
    try {
        Start-Toolkit
    } catch {
        Write-Host "✗ 錯誤: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor Gray
    }
}
