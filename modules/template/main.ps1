<#
.SYNOPSIS
    模組主腳本
.DESCRIPTION
    在此實作模組的核心功能
#>

# 載入共用工具
. "$PSScriptRoot\..\..\shared\utils.ps1"

# 模組主函數
function Start-TemplateModule {
    Write-Info "模組模板已啟動"
    Write-Host ""
    Write-Host "這是一個範例模組。" -ForegroundColor White
    Write-Host "請複製此目錄並修改以建立你自己的模組。" -ForegroundColor Gray
    Write-Host ""

    # 範例：顯示模組設定
    Write-Info "模組設定:"
    $script:CurrentModule.config.settings | ConvertTo-Json

    Write-Host ""
    Write-Success "模組執行完成"
}

# 執行模組
Start-TemplateModule
