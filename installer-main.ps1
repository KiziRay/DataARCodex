Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$script:InstallerRepo = "KiziRay/DataARCodex"

function Ensure-StaGuiSession {
    $state = [Threading.Thread]::CurrentThread.GetApartmentState()
    if ($state -eq [Threading.ApartmentState]::STA) {
        return
    }

    if ($env:PRR_GUI_STA -eq "1") {
        throw "Unable to launch GUI in STA mode."
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
        Write-UiLog -LogBox $LogBox -Message "Removed: $InstallPath"
    } else {
        Write-UiLog -LogBox $LogBox -Message "Not installed: $InstallPath"
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

    Write-UiLog -LogBox $LogBox -Message "Preparing install from repo: $Repo"

    if (Test-Path $InstallPath) {
        if (-not $Force) {
            throw "InstallPath already exists: $InstallPath. Use -Force to overwrite."
        }
        Write-UiLog -LogBox $LogBox -Message "Cleaning existing path: $InstallPath"
        Remove-Item -Path $InstallPath -Recurse -Force
    }

    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null

    $api = "https://api.github.com/repos/$Repo/releases/latest"
    Write-UiLog -LogBox $LogBox -Message "Query latest release: $api"
    $release = Invoke-RestMethod -Uri $api

    $asset = $release.assets |
        Where-Object { $_.name -match "windows" -and $_.name -match "x64" -and $_.name -match "\.zip$" } |
        Select-Object -First 1

    if (-not $asset) {
        throw "No windows x64 zip asset found in latest release."
    }

    $zipPath = Join-Path $env:TEMP "password_recovery_rust_latest.zip"
    Write-UiLog -LogBox $LogBox -Message "Download: $($asset.browser_download_url)"
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath

    Write-UiLog -LogBox $LogBox -Message "Extract to: $InstallPath"
    Expand-Archive -Path $zipPath -DestinationPath $InstallPath -Force
    Remove-Item $zipPath -Force

    $launcher = Join-Path $InstallPath "run.ps1"
@"
`$exe = Join-Path `$PSScriptRoot 'password_recovery_rust.exe'
if (-not (Test-Path `$exe)) { throw 'password_recovery_rust.exe not found' }
& `$exe `$args
"@ | Set-Content -Path $launcher -Encoding UTF8

    $uninstall = Join-Path $InstallPath "uninstall.ps1"
@"
Set-StrictMode -Version Latest
`$ErrorActionPreference = 'Stop'
Remove-Item -Path `"$InstallPath`" -Recurse -Force
Write-Host 'Uninstalled PasswordRecoveryRust'
"@ | Set-Content -Path $uninstall -Encoding UTF8

    Write-UiLog -LogBox $LogBox -Message "Installed successfully: $InstallPath"
    Write-UiLog -LogBox $LogBox -Message "Run: & '$launcher' recover --archive <file> --dict <wordlist>"
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

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Password Recovery Rust Utility"
    $form.StartPosition = "CenterScreen"
    $form.Size = New-Object System.Drawing.Size(900, 620)
    $form.BackColor = [System.Drawing.Color]::FromArgb(25, 29, 38)
    $form.ForeColor = [System.Drawing.Color]::White
    $form.Font = New-Object System.Drawing.Font("Segoe UI", 10)

    $title = New-Object System.Windows.Forms.Label
    $title.Text = "Password Recovery Rust - WinUtil Style"
    $title.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 16)
    $title.AutoSize = $true
    $title.Location = New-Object System.Drawing.Point(20, 15)

    $sub = New-Object System.Windows.Forms.Label
    $sub.Text = "Install / Reinstall / Uninstall from GitHub Release"
    $sub.AutoSize = $true
    $sub.ForeColor = [System.Drawing.Color]::FromArgb(170, 180, 200)
    $sub.Location = New-Object System.Drawing.Point(22, 50)

    $repoLabel = New-Object System.Windows.Forms.Label
    $repoLabel.Text = "GitHub Repo"
    $repoLabel.AutoSize = $true
    $repoLabel.Location = New-Object System.Drawing.Point(22, 95)

    $repoBox = New-Object System.Windows.Forms.TextBox
    $repoBox.Text = $DefaultRepo
    $repoBox.Size = New-Object System.Drawing.Size(580, 30)
    $repoBox.Location = New-Object System.Drawing.Point(22, 118)

    $pathLabel = New-Object System.Windows.Forms.Label
    $pathLabel.Text = "Install Path"
    $pathLabel.AutoSize = $true
    $pathLabel.Location = New-Object System.Drawing.Point(22, 160)

    $pathBox = New-Object System.Windows.Forms.TextBox
    $pathBox.Text = $DefaultInstallPath
    $pathBox.Size = New-Object System.Drawing.Size(580, 30)
    $pathBox.Location = New-Object System.Drawing.Point(22, 183)

    $btnInstall = New-Object System.Windows.Forms.Button
    $btnInstall.Text = "Install"
    $btnInstall.Size = New-Object System.Drawing.Size(140, 40)
    $btnInstall.Location = New-Object System.Drawing.Point(22, 235)

    $btnReinstall = New-Object System.Windows.Forms.Button
    $btnReinstall.Text = "Reinstall (Force)"
    $btnReinstall.Size = New-Object System.Drawing.Size(140, 40)
    $btnReinstall.Location = New-Object System.Drawing.Point(172, 235)

    $btnUninstall = New-Object System.Windows.Forms.Button
    $btnUninstall.Text = "Uninstall"
    $btnUninstall.Size = New-Object System.Drawing.Size(140, 40)
    $btnUninstall.Location = New-Object System.Drawing.Point(322, 235)

    $btnOpen = New-Object System.Windows.Forms.Button
    $btnOpen.Text = "Open Folder"
    $btnOpen.Size = New-Object System.Drawing.Size(140, 40)
    $btnOpen.Location = New-Object System.Drawing.Point(472, 235)

    $btnExit = New-Object System.Windows.Forms.Button
    $btnExit.Text = "Exit"
    $btnExit.Size = New-Object System.Drawing.Size(140, 40)
    $btnExit.Location = New-Object System.Drawing.Point(622, 235)

    $logLabel = New-Object System.Windows.Forms.Label
    $logLabel.Text = "Activity Log"
    $logLabel.AutoSize = $true
    $logLabel.Location = New-Object System.Drawing.Point(22, 295)

    $logBox = New-Object System.Windows.Forms.TextBox
    $logBox.Multiline = $true
    $logBox.ScrollBars = "Vertical"
    $logBox.ReadOnly = $true
    $logBox.BackColor = [System.Drawing.Color]::FromArgb(13, 17, 23)
    $logBox.ForeColor = [System.Drawing.Color]::FromArgb(186, 232, 255)
    $logBox.BorderStyle = "FixedSingle"
    $logBox.Font = New-Object System.Drawing.Font("Consolas", 10)
    $logBox.Location = New-Object System.Drawing.Point(22, 320)
    $logBox.Size = New-Object System.Drawing.Size(840, 240)

    $runAction = {
        param([scriptblock]$Action)
        try {
            $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
            & $Action
        } catch {
            Write-UiLog -LogBox $logBox -Message ("ERROR: " + $_.Exception.Message)
            [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "Installer Error", "OK", "Error") | Out-Null
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
            Start-Process explorer.exe $pathBox.Text
            Write-UiLog -LogBox $logBox -Message "Open folder: $($pathBox.Text)"
        } else {
            Write-UiLog -LogBox $logBox -Message "Path not found: $($pathBox.Text)"
        }
    })

    $btnExit.Add_Click({ $form.Close() })

    $form.Controls.AddRange(@(
        $title, $sub, $repoLabel, $repoBox, $pathLabel, $pathBox,
        $btnInstall, $btnReinstall, $btnUninstall, $btnOpen, $btnExit,
        $logLabel, $logBox
    ))

    Write-UiLog -LogBox $logBox -Message "UI ready. Choose an action."
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
