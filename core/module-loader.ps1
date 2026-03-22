<#
.SYNOPSIS
    模組載入器
.DESCRIPTION
    掃描並載入所有可用的模組
#>

function Get-AvailableModules {
    $modules = @()

    if (-not (Test-Path $script:ModulesPath)) {
        Write-Warning "模組目錄不存在: $script:ModulesPath"
        return $modules
    }

    $moduleDirs = Get-ChildItem -Path $script:ModulesPath -Directory

    foreach ($dir in $moduleDirs) {
        $configFile = Join-Path $dir.FullName "module.json"

        if (Test-Path $configFile) {
            try {
                $config = Get-Content $configFile -Raw | ConvertFrom-Json

                # 驗證必要欄位
                if (-not $config.name -or -not $config.version) {
                    Write-Warning "模組設定不完整: $($dir.Name)"
                    continue
                }

                # 檢查主腳本是否存在
                $mainScript = Join-Path $dir.FullName "main.ps1"
                if (-not (Test-Path $mainScript)) {
                    Write-Warning "找不到主腳本: $($dir.Name)/main.ps1"
                    continue
                }

                # 加入模組資訊
                $moduleInfo = [PSCustomObject]@{
                    name = $config.name
                    display_name = $config.display_name
                    version = $config.version
                    description = $config.description
                    author = $config.author
                    path = $dir.FullName
                    main_script = $mainScript
                    config = $config
                }

                $modules += $moduleInfo
            } catch {
                Write-Warning "載入模組失敗: $($dir.Name) - $($_.Exception.Message)"
            }
        }
    }

    return $modules
}

function Start-Module {
    param($Module)

    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  啟動模組: $($Module.display_name) v$($Module.version)" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""

    try {
        # 設定模組上下文
        $script:CurrentModule = $Module

        # 執行模組主腳本
        & $Module.main_script

    } catch {
        Write-Host "✗ 模組執行錯誤: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor Gray
    }
}
