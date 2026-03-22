<#
.SYNOPSIS
    UI 框架
.DESCRIPTION
    提供共用的 UI 元件和函數
#>

Add-Type -AssemblyName PresentationFramework -ErrorAction SilentlyContinue
Add-Type -AssemblyName PresentationCore -ErrorAction SilentlyContinue
Add-Type -AssemblyName WindowsBase -ErrorAction SilentlyContinue

function Show-MessageBox {
    param(
        [string]$Message,
        [string]$Title = "訊息",
        [string]$Type = "Information"
    )

    [System.Windows.MessageBox]::Show($Message, $Title, "OK", $Type)
}

function Show-InputDialog {
    param(
        [string]$Prompt,
        [string]$Title = "輸入",
        [string]$DefaultValue = ""
    )

    $result = [Microsoft.VisualBasic.Interaction]::InputBox($Prompt, $Title, $DefaultValue)
    return $result
}

function Show-FileDialog {
    param(
        [string]$Title = "選擇檔案",
        [string]$Filter = "所有檔案 (*.*)|*.*",
        [switch]$Save
    )

    Add-Type -AssemblyName System.Windows.Forms

    if ($Save) {
        $dialog = New-Object System.Windows.Forms.SaveFileDialog
    } else {
        $dialog = New-Object System.Windows.Forms.OpenFileDialog
    }

    $dialog.Title = $Title
    $dialog.Filter = $Filter

    if ($dialog.ShowDialog() -eq "OK") {
        return $dialog.FileName
    }

    return $null
}

function Show-FolderDialog {
    param(
        [string]$Description = "選擇資料夾"
    )

    Add-Type -AssemblyName System.Windows.Forms

    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = $Description

    if ($dialog.ShowDialog() -eq "OK") {
        return $dialog.SelectedPath
    }

    return $null
}

function Write-ColorText {
    param(
        [string]$Text,
        [string]$Color = "White"
    )

    Write-Host $Text -ForegroundColor $Color
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor Yellow
}

function Write-Info {
    param([string]$Message)
    Write-Host "▸ $Message" -ForegroundColor Cyan
}
