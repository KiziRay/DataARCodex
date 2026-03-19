Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$script:InstallerRepo = "KiziRay/DataARCodex"

function Ensure-StaGuiSession {
    $state = [Threading.Thread]::CurrentThread.GetApartmentState()
    if ($state -eq [Threading.ApartmentState]::STA) {
        return $false
    }

    if ($env:PRR_GUI_STA -eq "1") {
        throw "無法在 STA 模式啟動 GUI。"
    }

    $env:PRR_GUI_STA = "1"
    $cmd = @"
`$env:PRR_GUI_STA='1'
irm 'https://raw.githubusercontent.com/$script:InstallerRepo/main/installer-main.ps1' | iex
"@

    Start-Process -FilePath "powershell.exe" -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-STA",
        "-Command", $cmd
    ) | Out-Null

    return $true
}

function Write-UiLog {
    param(
        [System.Windows.Forms.TextBox]$LogBox,
        [string]$Message
    )

    $time = Get-Date -Format "HH:mm:ss"
    $line = "[$time] $Message"
    if ($null -ne $LogBox) {
        $LogBox.AppendText($line + [Environment]::NewLine)
        $LogBox.SelectionStart = $LogBox.TextLength
        $LogBox.ScrollToCaret()
    } else {
        Write-Host $line
    }
}

function Uninstall-PasswordRecoveryRust {
    [CmdletBinding()]
    param(
        [string]$InstallPath = "$env:LOCALAPPDATA\PasswordRecoveryRust",
        [System.Windows.Forms.TextBox]$LogBox
    )

    if (Test-Path $InstallPath) {
        Remove-Item -Path $InstallPath -Recurse -Force
        Write-UiLog -LogBox $LogBox -Message "已移除：$InstallPath"
    } else {
        Write-UiLog -LogBox $LogBox -Message "尚未安裝：$InstallPath"
    }
}

function Install-PasswordRecoveryRust {
    [CmdletBinding()]
    param(
        [string]$Repo = "KiziRay/DataARCodex",
        [string]$InstallPath = "$env:LOCALAPPDATA\PasswordRecoveryRust",
        [switch]$Force,
        [System.Windows.Forms.TextBox]$LogBox
    )

    Write-UiLog -LogBox $LogBox -Message "準備從儲存庫安裝：$Repo"

    if (Test-Path $InstallPath) {
        if (-not $Force) {
            throw "安裝路徑已存在：$InstallPath。請使用 -Force 覆蓋。"
        }
        Write-UiLog -LogBox $LogBox -Message "清除既有路徑：$InstallPath"
        Remove-Item -Path $InstallPath -Recurse -Force
    }

    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null

    $api = "https://api.github.com/repos/$Repo/releases/latest"
    Write-UiLog -LogBox $LogBox -Message "查詢最新版本資訊：$api"
    $release = Invoke-RestMethod -Uri $api

    $asset = $release.assets |
        Where-Object { $_.name -match "windows" -and $_.name -match "x64" -and $_.name -match "\.zip$" } |
        Select-Object -First 1

    if (-not $asset) {
        throw "最新版本找不到 Windows x64 的 zip 安裝檔。"
    }

    $zipPath = Join-Path $env:TEMP "password_recovery_rust_latest.zip"
    Write-UiLog -LogBox $LogBox -Message "下載：$($asset.browser_download_url)"
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath

    Write-UiLog -LogBox $LogBox -Message "解壓縮至：$InstallPath"
    Expand-Archive -Path $zipPath -DestinationPath $InstallPath -Force
    Remove-Item $zipPath -Force

    $launcher = Join-Path $InstallPath "run.ps1"
@"
`$exe = Join-Path `$PSScriptRoot 'password_recovery_rust.exe'
if (-not (Test-Path `$exe)) { throw '找不到 password_recovery_rust.exe' }
& `$exe `$args
"@ | Set-Content -Path $launcher -Encoding UTF8

    $uninstall = Join-Path $InstallPath "uninstall.ps1"
@"
Set-StrictMode -Version Latest
`$ErrorActionPreference = 'Stop'
Remove-Item -Path `"$InstallPath`" -Recurse -Force
Write-Host '已解除安裝 PasswordRecoveryRust'
"@ | Set-Content -Path $uninstall -Encoding UTF8

    Write-UiLog -LogBox $LogBox -Message "安裝完成：$InstallPath"
    Write-UiLog -LogBox $LogBox -Message "執行：& '$launcher' recover --archive <file> --dict <wordlist>"
}

function Show-WinUtilStyleInstaller {
    [CmdletBinding()]
    param(
        [string]$DefaultRepo = "KiziRay/DataARCodex",
        [string]$DefaultInstallPath = "$env:LOCALAPPDATA\PasswordRecoveryRust"
    )

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    [System.Windows.Forms.Application]::EnableVisualStyles()

    $bg = [System.Drawing.Color]::FromArgb(245, 247, 251)
    $panelBg = [System.Drawing.Color]::White
    $accent = [System.Drawing.Color]::FromArgb(32, 99, 220)
    $muted = [System.Drawing.Color]::FromArgb(94, 104, 125)
    $danger = [System.Drawing.Color]::FromArgb(196, 48, 43)

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "壓縮檔密碼解鎖工具安裝程式"
    $form.StartPosition = "CenterScreen"
    $form.Size = New-Object System.Drawing.Size(980, 700)
    $form.MinimumSize = New-Object System.Drawing.Size(960, 680)
    $form.BackColor = $bg
    $form.ForeColor = [System.Drawing.Color]::FromArgb(20, 24, 33)
    $form.Font = New-Object System.Drawing.Font("Microsoft JhengHei UI", 10)

    $header = New-Object System.Windows.Forms.Panel
    $header.BackColor = $accent
    $header.Location = New-Object System.Drawing.Point(0, 0)
    $header.Size = New-Object System.Drawing.Size(980, 86)
    $header.Anchor = "Top,Left,Right"

    $title = New-Object System.Windows.Forms.Label
    $title.Text = "壓縮檔密碼解鎖工具安裝中心"
    $title.Font = New-Object System.Drawing.Font("Microsoft JhengHei UI", 16, [System.Drawing.FontStyle]::Bold)
    $title.AutoSize = $true
    $title.ForeColor = [System.Drawing.Color]::White
    $title.Location = New-Object System.Drawing.Point(24, 16)

    $sub = New-Object System.Windows.Forms.Label
    $sub.Text = "主要功能：ZIP/RAR/7z 密碼解鎖（每次執行指令都會開啟此介面）"
    $sub.AutoSize = $true
    $sub.ForeColor = [System.Drawing.Color]::FromArgb(226, 233, 245)
    $sub.Location = New-Object System.Drawing.Point(26, 50)

    $header.Controls.AddRange(@($title, $sub))

    $configPanel = New-Object System.Windows.Forms.Panel
    $configPanel.BackColor = $panelBg
    $configPanel.Location = New-Object System.Drawing.Point(20, 104)
    $configPanel.Size = New-Object System.Drawing.Size(930, 190)
    $configPanel.Anchor = "Top,Left,Right"
    $configPanel.BorderStyle = "FixedSingle"

    $configTitle = New-Object System.Windows.Forms.Label
    $configTitle.Text = "設定"
    $configTitle.Font = New-Object System.Drawing.Font("Microsoft JhengHei UI", 12, [System.Drawing.FontStyle]::Bold)
    $configTitle.AutoSize = $true
    $configTitle.Location = New-Object System.Drawing.Point(16, 14)

    $repoLabel = New-Object System.Windows.Forms.Label
    $repoLabel.Text = "來源倉庫"
    $repoLabel.AutoSize = $true
    $repoLabel.ForeColor = $muted
    $repoLabel.Location = New-Object System.Drawing.Point(18, 54)

    $repoBox = New-Object System.Windows.Forms.TextBox
    $repoBox.Text = $DefaultRepo
    $repoBox.Size = New-Object System.Drawing.Size(885, 30)
    $repoBox.Location = New-Object System.Drawing.Point(18, 75)
    $repoBox.Anchor = "Top,Left,Right"

    $pathLabel = New-Object System.Windows.Forms.Label
    $pathLabel.Text = "安裝路徑"
    $pathLabel.AutoSize = $true
    $pathLabel.ForeColor = $muted
    $pathLabel.Location = New-Object System.Drawing.Point(18, 116)

    $pathBox = New-Object System.Windows.Forms.TextBox
    $pathBox.Text = $DefaultInstallPath
    $pathBox.Size = New-Object System.Drawing.Size(885, 30)
    $pathBox.Location = New-Object System.Drawing.Point(18, 137)
    $pathBox.Anchor = "Top,Left,Right"

    $configPanel.Controls.AddRange(@($configTitle, $repoLabel, $repoBox, $pathLabel, $pathBox))

    $actionPanel = New-Object System.Windows.Forms.Panel
    $actionPanel.BackColor = $panelBg
    $actionPanel.Location = New-Object System.Drawing.Point(20, 308)
    $actionPanel.Size = New-Object System.Drawing.Size(930, 86)
    $actionPanel.Anchor = "Top,Left,Right"
    $actionPanel.BorderStyle = "FixedSingle"

    $btnInstall = New-Object System.Windows.Forms.Button
    $btnInstall.Text = "安裝"
    $btnInstall.Size = New-Object System.Drawing.Size(170, 44)
    $btnInstall.Location = New-Object System.Drawing.Point(16, 20)

    $btnReinstall = New-Object System.Windows.Forms.Button
    $btnReinstall.Text = "重新安裝（強制）"
    $btnReinstall.Size = New-Object System.Drawing.Size(190, 44)
    $btnReinstall.Location = New-Object System.Drawing.Point(196, 20)

    $btnUninstall = New-Object System.Windows.Forms.Button
    $btnUninstall.Text = "解除安裝"
    $btnUninstall.Size = New-Object System.Drawing.Size(170, 44)
    $btnUninstall.Location = New-Object System.Drawing.Point(396, 20)

    $btnOpen = New-Object System.Windows.Forms.Button
    $btnOpen.Text = "啟動解鎖工具"
    $btnOpen.Size = New-Object System.Drawing.Size(190, 44)
    $btnOpen.Location = New-Object System.Drawing.Point(576, 20)

    $btnExit = New-Object System.Windows.Forms.Button
    $btnExit.Text = "關閉"
    $btnExit.Size = New-Object System.Drawing.Size(140, 44)
    $btnExit.Location = New-Object System.Drawing.Point(776, 20)
    $btnExit.Anchor = "Top,Right"

    foreach ($btn in @($btnInstall, $btnReinstall, $btnUninstall, $btnOpen, $btnExit)) {
        $btn.FlatStyle = "Flat"
        $btn.FlatAppearance.BorderSize = 0
        $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
        $btn.Font = New-Object System.Drawing.Font("Microsoft JhengHei UI", 10, [System.Drawing.FontStyle]::Bold)
        $btn.ForeColor = [System.Drawing.Color]::White
    }
    $btnInstall.BackColor = $accent
    $btnReinstall.BackColor = [System.Drawing.Color]::FromArgb(50, 123, 244)
    $btnUninstall.BackColor = $danger
    $btnOpen.BackColor = [System.Drawing.Color]::FromArgb(72, 78, 92)
    $btnExit.BackColor = [System.Drawing.Color]::FromArgb(108, 116, 136)

    $actionPanel.Controls.AddRange(@($btnInstall, $btnReinstall, $btnUninstall, $btnOpen, $btnExit))

    $logPanel = New-Object System.Windows.Forms.Panel
    $logPanel.BackColor = $panelBg
    $logPanel.Location = New-Object System.Drawing.Point(20, 408)
    $logPanel.Size = New-Object System.Drawing.Size(930, 236)
    $logPanel.Anchor = "Top,Bottom,Left,Right"
    $logPanel.BorderStyle = "FixedSingle"

    $logLabel = New-Object System.Windows.Forms.Label
    $logLabel.Text = "操作紀錄"
    $logLabel.Font = New-Object System.Drawing.Font("Microsoft JhengHei UI", 11, [System.Drawing.FontStyle]::Bold)
    $logLabel.AutoSize = $true
    $logLabel.Location = New-Object System.Drawing.Point(16, 12)

    $logBox = New-Object System.Windows.Forms.TextBox
    $logBox.Multiline = $true
    $logBox.ScrollBars = "Vertical"
    $logBox.ReadOnly = $true
    $logBox.BackColor = [System.Drawing.Color]::FromArgb(250, 251, 254)
    $logBox.ForeColor = [System.Drawing.Color]::FromArgb(34, 44, 64)
    $logBox.BorderStyle = "FixedSingle"
    $logBox.Font = New-Object System.Drawing.Font("Microsoft JhengHei UI", 10)
    $logBox.Location = New-Object System.Drawing.Point(16, 38)
    $logBox.Size = New-Object System.Drawing.Size(895, 180)
    $logBox.Anchor = "Top,Bottom,Left,Right"

    $logPanel.Controls.AddRange(@($logLabel, $logBox))

    $runAction = {
        param([scriptblock]$Action)
        try {
            $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
            & $Action
        } catch {
            Write-UiLog -LogBox $logBox -Message ("錯誤：" + $_.Exception.Message)
            [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "操作失敗", "OK", "Error") | Out-Null
        } finally {
            $form.Cursor = [System.Windows.Forms.Cursors]::Default
        }
    }

    $btnInstall.Add_Click({
        & $runAction {
            Install-PasswordRecoveryRust -Repo $repoBox.Text -InstallPath $pathBox.Text -LogBox $logBox
        }
    })

    $btnReinstall.Add_Click({
        & $runAction {
            Install-PasswordRecoveryRust -Repo $repoBox.Text -InstallPath $pathBox.Text -Force -LogBox $logBox
        }
    })

    $btnUninstall.Add_Click({
        & $runAction {
            Uninstall-PasswordRecoveryRust -InstallPath $pathBox.Text -LogBox $logBox
        }
    })

    $btnOpen.Add_Click({
        if (Test-Path $pathBox.Text) {
            $runner = Join-Path $pathBox.Text "run.ps1"
            if (Test-Path $runner) {
                Start-Process powershell.exe -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $runner)
                Write-UiLog -LogBox $logBox -Message "已啟動解鎖工具。"
            } else {
                Write-UiLog -LogBox $logBox -Message "尚未安裝完成，找不到 run.ps1。"
            }
        } else {
            Write-UiLog -LogBox $logBox -Message "找不到路徑：$($pathBox.Text)"
        }
    })

    $btnExit.Add_Click({ $form.Close() })

    $form.Controls.AddRange(@($header, $configPanel, $actionPanel, $logPanel))

    Write-UiLog -LogBox $logBox -Message "介面已就緒，請選擇要執行的項目。"
    [void]$form.ShowDialog()
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $relaunched = Ensure-StaGuiSession
        if (-not $relaunched) {
            Show-WinUtilStyleInstaller
        }
    } catch {
        Write-Error $_
    }
}
