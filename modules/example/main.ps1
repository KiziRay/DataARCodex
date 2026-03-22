<#
.SYNOPSIS
    範例模組
.DESCRIPTION
    展示如何建立模組的範例
#>

. "$PSScriptRoot\..\..\shared\utils.ps1"

function Start-ExampleModule {
    Write-Info "範例模組已啟動"
    Write-Host ""

    # 顯示選單
    while ($true) {
        Write-Host "請選擇功能:" -ForegroundColor Cyan
        Write-Host "  [1] 顯示系統資訊"
        Write-Host "  [2] 產生隨機密碼"
        Write-Host "  [3] 計算檔案雜湊"
        Write-Host "  [0] 返回"
        Write-Host ""
        Write-Host -NoNewline "請選擇: " -ForegroundColor Cyan

        $choice = Read-Host
        Write-Host ""

        switch ($choice) {
            "1" { Show-SystemInfo }
            "2" { Generate-RandomPassword }
            "3" { Calculate-FileHash }
            "0" { return }
            default { Write-Error "無效的選擇" }
        }

        Write-Host ""
    }
}

function Show-SystemInfo {
    Write-Info "系統資訊"
    Write-Host "  作業系統: $([System.Environment]::OSVersion.VersionString)" -ForegroundColor White
    Write-Host "  電腦名稱: $env:COMPUTERNAME" -ForegroundColor White
    Write-Host "  使用者名稱: $env:USERNAME" -ForegroundColor White
    Write-Host "  PowerShell 版本: $($PSVersionTable.PSVersion)" -ForegroundColor White
    Write-Host "  管理員權限: $(if (Test-Administrator) { '是' } else { '否' })" -ForegroundColor White
}

function Generate-RandomPassword {
    Write-Host -NoNewline "密碼長度 (預設 16): " -ForegroundColor Cyan
    $length = Read-Host
    if (-not $length) { $length = 16 }

    $password = Get-RandomString -Length ([int]$length) -AlphaNumericOnly

    Write-Success "已產生密碼"
    Write-Host "  $password" -ForegroundColor Yellow

    # 複製到剪貼簿
    Set-Clipboard -Value $password
    Write-Info "已複製到剪貼簿"
}

function Calculate-FileHash {
    $file = Show-FileDialog -Title "選擇要計算雜湊的檔案"

    if ($file) {
        Write-Info "計算中..."
        try {
            $hash = Get-FileHash256 -FilePath $file
            Write-Success "檔案雜湊 (SHA256)"
            Write-Host "  檔案: $file" -ForegroundColor Gray
            Write-Host "  雜湊: $hash" -ForegroundColor Yellow

            Set-Clipboard -Value $hash
            Write-Info "已複製到剪貼簿"
        } catch {
            Write-Error "計算失敗: $($_.Exception.Message)"
        }
    } else {
        Write-Warning "未選擇檔案"
    }
}

# 執行模組
Start-ExampleModule
