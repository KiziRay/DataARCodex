<#
.SYNOPSIS
    CipherBreak — 壓縮檔密碼解鎖工具 (WPF GUI)
.DESCRIPTION
    irm https://raw.githubusercontent.com/KiziRay/DataARCodex/main/install.ps1 | iex
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$script:Repo = "KiziRay/DataARCodex"
$script:DefaultInstall = "$env:LOCALAPPDATA\PasswordRecoveryRust"
$script:SettingsFile = "$env:LOCALAPPDATA\CipherBreak\settings.json"

# ══════════════════════════════════════════
#  STA Mode
# ══════════════════════════════════════════
function Ensure-Sta {
    if ([Threading.Thread]::CurrentThread.GetApartmentState() -eq [Threading.ApartmentState]::STA) {
        return $false
    }
    if ($env:CB_STA -eq "1") { throw "Cannot switch to STA. GUI must run in STA." }
    $env:CB_STA = "1"
    if ($PSCommandPath -and (Test-Path $PSCommandPath)) {
        Start-Process powershell.exe -ArgumentList @(
            "-NoProfile","-ExecutionPolicy","Bypass","-STA","-File",$PSCommandPath
        ) | Out-Null
    } else {
        $cmd = "`$env:CB_STA='1'; iex ((irm 'https://raw.githubusercontent.com/$script:Repo/main/installer-main.ps1').TrimStart([char]0xFEFF))"
        Start-Process powershell.exe -ArgumentList @(
            "-NoProfile","-ExecutionPolicy","Bypass","-STA","-Command",$cmd
        ) | Out-Null
    }
    return $true
}

# ══════════════════════════════════════════
#  Settings
# ══════════════════════════════════════════
function Get-CbSettings {
    if (Test-Path $script:SettingsFile) {
        try { return (Get-Content $script:SettingsFile -Raw | ConvertFrom-Json) }
        catch { return [PSCustomObject]@{} }
    }
    return [PSCustomObject]@{}
}
function Save-CbSettings($obj) {
    $dir = Split-Path $script:SettingsFile
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $obj | ConvertTo-Json -Depth 4 | Set-Content $script:SettingsFile -Encoding UTF8
}

# ══════════════════════════════════════════
#  Find CLI exe
# ══════════════════════════════════════════
function Find-CbExe {
    $s = Get-CbSettings
    $base = if ($s.PSObject.Properties['installPath'] -and $s.installPath) { $s.installPath } else { $script:DefaultInstall }
    $exe = Join-Path $base "password_recovery_rust.exe"
    if (Test-Path $exe) { return $exe }
    $inPath = Get-Command "password_recovery_rust" -ErrorAction SilentlyContinue
    if ($inPath) { return $inPath.Source }
    return $null
}

# ══════════════════════════════════════════
#  Main GUI
# ══════════════════════════════════════════
function Show-CipherBreak {
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase

    $xaml = @'
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="CipherBreak — 壓縮檔密碼解鎖工具"
    Width="1120" Height="790" MinWidth="820" MinHeight="620"
    WindowStartupLocation="CenterScreen"
    Background="#0f1728" Foreground="#e2e8f0"
    FontFamily="Microsoft JhengHei UI, Segoe UI" FontSize="13">

  <Window.Resources>
    <BooleanToVisibilityConverter x:Key="b2v"/>

    <!-- Dark TextBox -->
    <Style x:Key="Input" TargetType="TextBox">
      <Setter Property="Foreground" Value="#e2e8f0"/>
      <Setter Property="CaretBrush" Value="#e2e8f0"/>
      <Setter Property="FontFamily" Value="Cascadia Code,Consolas,Courier New"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="TextBox">
            <Border x:Name="bd" Background="#0d1117" BorderBrush="#2d3654"
                    BorderThickness="1" CornerRadius="6" Padding="10,8">
              <ScrollViewer x:Name="PART_ContentHost" Focusable="False"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsKeyboardFocused" Value="True">
                <Setter TargetName="bd" Property="BorderBrush" Value="#6366f1"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Primary Button (set Background per-button to change color) -->
    <Style x:Key="Btn" TargetType="Button">
      <Setter Property="Background" Value="#6366f1"/>
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="FontWeight" Value="Bold"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Grid>
              <Border x:Name="bg" Background="{TemplateBinding Background}" CornerRadius="6"/>
              <Border x:Name="ov" Background="White" CornerRadius="6" Opacity="0"/>
              <Border CornerRadius="6" Padding="22,10">
                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
              </Border>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="ov" Property="Opacity" Value="0.10"/>
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter TargetName="ov" Property="Opacity" Value="0.18"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter TargetName="bg" Property="Opacity" Value="0.4"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Ghost Button -->
    <Style x:Key="BtnGhost" TargetType="Button">
      <Setter Property="Foreground" Value="#94a3b8"/>
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd" Background="Transparent" BorderBrush="#2d3654"
                    BorderThickness="1" CornerRadius="5" Padding="12,5">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd" Property="BorderBrush" Value="#64748b"/>
                <Setter Property="Foreground" Value="#e2e8f0"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Tab Nav RadioButton -->
    <Style x:Key="TabBtn" TargetType="RadioButton">
      <Setter Property="Foreground" Value="#64748b"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="RadioButton">
            <Border x:Name="bd" Background="Transparent" CornerRadius="6"
                    Padding="15,8" Margin="0,0,3,0">
              <ContentPresenter HorizontalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#6366f1"/>
                <Setter Property="Foreground" Value="White"/>
              </Trigger>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#1e293b"/>
              </Trigger>
              <MultiTrigger>
                <MultiTrigger.Conditions>
                  <Condition Property="IsChecked" Value="True"/>
                  <Condition Property="IsMouseOver" Value="True"/>
                </MultiTrigger.Conditions>
                <Setter TargetName="bd" Property="Background" Value="#818cf8"/>
              </MultiTrigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Mode Toggle RadioButton -->
    <Style x:Key="ModeBtn" TargetType="RadioButton">
      <Setter Property="Foreground" Value="#64748b"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="RadioButton">
            <Border x:Name="bd" Background="Transparent" BorderBrush="#2d3654"
                    BorderThickness="1" Padding="16,7" Margin="0,0,-1,0">
              <ContentPresenter HorizontalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#1e1b4b"/>
                <Setter TargetName="bd" Property="BorderBrush" Value="#6366f1"/>
                <Setter Property="Foreground" Value="#a5b4fc"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>

  <DockPanel>
    <!-- ═══ Header ═══ -->
    <Border DockPanel.Dock="Top" Padding="22,14" BorderBrush="#1a2035" BorderThickness="0,0,0,1">
      <Border.Background>
        <LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
          <GradientStop Color="#16103a" Offset="0"/>
          <GradientStop Color="#0c1a30" Offset="1"/>
        </LinearGradientBrush>
      </Border.Background>
      <Grid>
        <StackPanel Orientation="Horizontal">
          <Border Background="#6366f1" CornerRadius="10" Width="40" Height="40" Margin="0,0,14,0">
            <TextBlock Text="&#x1F512;" FontSize="18" HorizontalAlignment="Center" VerticalAlignment="Center"/>
          </Border>
          <StackPanel VerticalAlignment="Center">
            <TextBlock FontSize="20" FontWeight="Bold">
              <TextBlock.Foreground>
                <LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
                  <GradientStop Color="#e2e8f0" Offset="0"/>
                  <GradientStop Color="#22d3ee" Offset="1"/>
                </LinearGradientBrush>
              </TextBlock.Foreground>
              CipherBreak
            </TextBlock>
            <TextBlock Text="壓縮檔密碼解鎖工具 · ZIP / RAR / 7z" FontSize="11" Foreground="#4b5563"/>
          </StackPanel>
        </StackPanel>
        <Border HorizontalAlignment="Right" VerticalAlignment="Center"
                Background="#071a12" CornerRadius="12" Padding="12,4" BorderBrush="#14532d" BorderThickness="1">
          <TextBlock Name="lblStatus" Text="● 就緒" Foreground="#10b981" FontSize="11" FontWeight="SemiBold"/>
        </Border>
      </Grid>
    </Border>

    <!-- ═══ Tab Nav ═══ -->
    <Border DockPanel.Dock="Top" Background="#111827" Padding="18,6" BorderBrush="#1a2035" BorderThickness="0,0,0,1">
      <WrapPanel>
        <RadioButton Name="tabExtract"  GroupName="nav" IsChecked="True" Content="提取 Hash"   Style="{StaticResource TabBtn}"/>
        <RadioButton Name="tabJohn"     GroupName="nav" Content="John 破解"   Style="{StaticResource TabBtn}"/>
        <RadioButton Name="tabHashcat"  GroupName="nav" Content="Hashcat GPU" Style="{StaticResource TabBtn}"/>
        <RadioButton Name="tabQuick"    GroupName="nav" Content="快速模式"    Style="{StaticResource TabBtn}"/>
        <RadioButton Name="tabInstall"  GroupName="nav" Content="安裝管理"    Style="{StaticResource TabBtn}" Margin="14,0,0,0"/>
        <RadioButton Name="tabSettings" GroupName="nav" Content="設定"        Style="{StaticResource TabBtn}"/>
      </WrapPanel>
    </Border>

    <!-- ═══ Log Panel ═══ -->
    <Border DockPanel.Dock="Bottom" Background="#080c14" BorderBrush="#1a2035" BorderThickness="0,1,0,0">
      <DockPanel>
        <Border DockPanel.Dock="Top" Padding="14,6" BorderBrush="#111520" BorderThickness="0,0,0,1">
          <Grid>
            <TextBlock Text="▶  執 行 日 誌" Foreground="#374151" FontSize="11" FontWeight="Bold"
                       VerticalAlignment="Center"/>
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
              <Button Name="btnCopyLog"  Content="複製" Style="{StaticResource BtnGhost}" Margin="0,0,6,0"/>
              <Button Name="btnClearLog" Content="清除" Style="{StaticResource BtnGhost}"/>
            </StackPanel>
          </Grid>
        </Border>
        <TextBox Name="txtLog" IsReadOnly="True" TextWrapping="Wrap"
                 VerticalScrollBarVisibility="Auto" AcceptsReturn="True"
                 Background="#080c14" Foreground="#94a3b8" BorderThickness="0"
                 FontFamily="Cascadia Code,Consolas,Courier New" FontSize="12"
                 Padding="14,8" Height="160"/>
      </DockPanel>
    </Border>

    <!-- ═══ Content ═══ -->
    <ScrollViewer VerticalScrollBarVisibility="Auto" Background="#0f1728" Padding="0">
      <Grid Margin="28,22">

        <!-- ── Panel: Extract Hash ── -->
        <StackPanel Visibility="{Binding IsChecked, ElementName=tabExtract, Converter={StaticResource b2v}}">
          <TextBlock Text="提取 Hash" FontSize="18" FontWeight="Bold" Margin="0,0,0,4"/>
          <TextBlock Text="使用 John 工具鏈（zip2john / rar2john / 7z2john）提取壓縮檔密碼雜湊" FontSize="12" Foreground="#64748b" Margin="0,0,0,20"/>
          <Grid>
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="*"/><ColumnDefinition Width="18"/><ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <Grid.RowDefinitions><RowDefinition/><RowDefinition/></Grid.RowDefinitions>
            <StackPanel Grid.Row="0" Grid.Column="0" Margin="0,0,0,14">
              <TextBlock Text="壓縮檔路徑 *" FontSize="12" Foreground="#94a3b8" Margin="0,0,0,4"/>
              <TextBox Name="txtExtArchive" Style="{StaticResource Input}"/>
            </StackPanel>
            <StackPanel Grid.Row="0" Grid.Column="2" Margin="0,0,0,14">
              <TextBlock Text="輸出 Hash 檔" FontSize="12" Foreground="#94a3b8" Margin="0,0,0,4"/>
              <TextBox Name="txtExtHashOut" Text="hash.txt" Style="{StaticResource Input}"/>
            </StackPanel>
            <StackPanel Grid.Row="1" Grid.Column="0" Margin="0,0,0,14">
              <TextBlock Text="John 目錄" FontSize="12" Foreground="#94a3b8" Margin="0,0,0,4"/>
              <TextBox Name="txtExtJohnDir" Style="{StaticResource Input}"/>
            </StackPanel>
            <StackPanel Grid.Row="1" Grid.Column="2" Margin="0,0,0,14">
              <TextBlock Text="Perl 路徑（7z 需要）" FontSize="12" Foreground="#94a3b8" Margin="0,0,0,4"/>
              <TextBox Name="txtExtPerl" Style="{StaticResource Input}"/>
            </StackPanel>
          </Grid>
          <Button Name="btnExtract" Content="提取 Hash" Style="{StaticResource Btn}" HorizontalAlignment="Left" Margin="0,6,0,0"/>
        </StackPanel>

        <!-- ── Panel: John Crack ── -->
        <StackPanel Visibility="{Binding IsChecked, ElementName=tabJohn, Converter={StaticResource b2v}}">
          <TextBlock Text="John the Ripper 字典破解" FontSize="18" FontWeight="Bold" Margin="0,0,0,4"/>
          <TextBlock Text="使用 John the Ripper 進行 CPU 字典攻擊（將在新視窗中執行）" FontSize="12" Foreground="#64748b" Margin="0,0,0,20"/>
          <Grid>
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="*"/><ColumnDefinition Width="18"/><ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <StackPanel Grid.Column="0" Margin="0,0,0,14">
              <TextBlock Text="Hash 檔案 *" FontSize="12" Foreground="#94a3b8" Margin="0,0,0,4"/>
              <TextBox Name="txtJohnHash" Style="{StaticResource Input}"/>
            </StackPanel>
            <StackPanel Grid.Column="2" Margin="0,0,0,14">
              <TextBlock Text="字典檔" FontSize="12" Foreground="#94a3b8" Margin="0,0,0,4"/>
              <TextBox Name="txtJohnWordlist" Style="{StaticResource Input}"/>
            </StackPanel>
          </Grid>
          <StackPanel Margin="0,0,0,14">
            <TextBlock Text="john.exe 路徑" FontSize="12" Foreground="#94a3b8" Margin="0,0,0,4"/>
            <TextBox Name="txtJohnExe" Style="{StaticResource Input}"/>
          </StackPanel>
          <Button Name="btnJohn" Content="開始破解" Style="{StaticResource Btn}" HorizontalAlignment="Left" Margin="0,6,0,0"/>
        </StackPanel>

        <!-- ── Panel: Hashcat GPU ── -->
        <StackPanel Visibility="{Binding IsChecked, ElementName=tabHashcat, Converter={StaticResource b2v}}">
          <TextBlock Text="Hashcat GPU 破解" FontSize="18" FontWeight="Bold" Margin="0,0,0,4"/>
          <TextBlock Text="使用 GPU 加速的 Hashcat 進行高速破解（將在新視窗中執行）" FontSize="12" Foreground="#64748b" Margin="0,0,0,20"/>
          <Grid>
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="*"/><ColumnDefinition Width="18"/><ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <Grid.RowDefinitions><RowDefinition/><RowDefinition/><RowDefinition/></Grid.RowDefinitions>
            <StackPanel Grid.Row="0" Grid.Column="0" Margin="0,0,0,14">
              <TextBlock Text="Hash 檔案 *" FontSize="12" Foreground="#94a3b8" Margin="0,0,0,4"/>
              <TextBox Name="txtHcHash" Style="{StaticResource Input}"/>
            </StackPanel>
            <StackPanel Grid.Row="0" Grid.Column="2" Margin="0,0,0,14">
              <TextBlock FontSize="12" Foreground="#94a3b8" Margin="0,0,0,4">
                <Run Text="模式 -m"/><Run Text="  (11600=7z  13000=RAR5  13600=WinZip  17200=PKZIP  23700=RAR3)" Foreground="#374151" FontSize="10"/>
              </TextBlock>
              <TextBox Name="txtHcMode" Text="13000" Style="{StaticResource Input}"/>
            </StackPanel>
            <StackPanel Grid.Row="1" Grid.Column="0" Margin="0,0,0,14">
              <TextBlock Text="攻擊模式 -a  (0=字典  3=暴力/Mask)" FontSize="12" Foreground="#94a3b8" Margin="0,0,0,4"/>
              <TextBox Name="txtHcAttack" Text="3" Style="{StaticResource Input}"/>
            </StackPanel>
            <StackPanel Grid.Row="1" Grid.Column="2" Margin="0,0,0,14">
              <TextBlock Text="Mask（-a 3 時）" FontSize="12" Foreground="#94a3b8" Margin="0,0,0,4"/>
              <TextBox Name="txtHcMask" Text="?d?d?d?d?d?d?d?d" Style="{StaticResource Input}"/>
            </StackPanel>
            <StackPanel Grid.Row="2" Grid.Column="0" Margin="0,0,0,14">
              <TextBlock Text="字典檔（-a 0 時）" FontSize="12" Foreground="#94a3b8" Margin="0,0,0,4"/>
              <TextBox Name="txtHcWordlist" Style="{StaticResource Input}"/>
            </StackPanel>
            <StackPanel Grid.Row="2" Grid.Column="2" Margin="0,0,0,14">
              <TextBlock Text="hashcat.exe 路徑" FontSize="12" Foreground="#94a3b8" Margin="0,0,0,4"/>
              <TextBox Name="txtHcExe" Style="{StaticResource Input}"/>
            </StackPanel>
          </Grid>
          <Button Name="btnHashcat" Content="開始 GPU 破解" Style="{StaticResource Btn}" HorizontalAlignment="Left" Margin="0,6,0,0"/>
        </StackPanel>

        <!-- ── Panel: Quick Mode ── -->
        <StackPanel Visibility="{Binding IsChecked, ElementName=tabQuick, Converter={StaticResource b2v}}">
          <TextBlock Text="快速模式" FontSize="18" FontWeight="Bold" Margin="0,0,0,4"/>
          <TextBlock Text="使用內建 7z 驗證引擎，不需要 John 或 Hashcat（需要 7z 在 PATH）" FontSize="12" Foreground="#64748b" Margin="0,0,0,20"/>
          <Grid Margin="0,0,0,16">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="*"/><ColumnDefinition Width="18"/><ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <StackPanel Grid.Column="0">
              <TextBlock Text="壓縮檔路徑 *" FontSize="12" Foreground="#94a3b8" Margin="0,0,0,4"/>
              <TextBox Name="txtQuickArchive" Style="{StaticResource Input}"/>
            </StackPanel>
            <StackPanel Grid.Column="2">
              <TextBlock Text="執行緒數" FontSize="12" Foreground="#94a3b8" Margin="0,0,0,4"/>
              <TextBox Name="txtQuickThreads" Text="8" Style="{StaticResource Input}"/>
            </StackPanel>
          </Grid>
          <StackPanel Orientation="Horizontal" Margin="0,0,0,16">
            <RadioButton Name="rbDict" GroupName="qmode" IsChecked="True" Content="字典攻擊" Style="{StaticResource ModeBtn}"/>
            <RadioButton Name="rbMask" GroupName="qmode" Content="Mask 攻擊" Style="{StaticResource ModeBtn}"/>
          </StackPanel>
          <StackPanel Visibility="{Binding IsChecked, ElementName=rbDict, Converter={StaticResource b2v}}" Margin="0,0,0,14">
            <TextBlock Text="字典檔路徑 *" FontSize="12" Foreground="#94a3b8" Margin="0,0,0,4"/>
            <TextBox Name="txtQuickDict" Style="{StaticResource Input}"/>
          </StackPanel>
          <StackPanel Visibility="{Binding IsChecked, ElementName=rbMask, Converter={StaticResource b2v}}">
            <StackPanel Margin="0,0,0,10">
              <TextBlock Text="Mask 模式 *" FontSize="12" Foreground="#94a3b8" Margin="0,0,0,4"/>
              <TextBox Name="txtQuickMask" Style="{StaticResource Input}"/>
            </StackPanel>
            <Border Background="#0a1a20" BorderBrush="#164e63" BorderThickness="1" CornerRadius="6" Padding="12,8">
              <TextBlock FontSize="11" Foreground="#22d3ee">
                <Run Text="Mask 語法："/><Run Text="?d" FontWeight="Bold"/><Run Text=" 數字 · "/>
                <Run Text="?l" FontWeight="Bold"/><Run Text=" 小寫 · "/>
                <Run Text="?u" FontWeight="Bold"/><Run Text=" 大寫 · "/>
                <Run Text="?s" FontWeight="Bold"/><Run Text=" 符號 · "/>
                <Run Text="?a" FontWeight="Bold"/><Run Text=" 全部"/>
              </TextBlock>
            </Border>
          </StackPanel>
          <Button Name="btnQuick" Content="開始破解" Style="{StaticResource Btn}" HorizontalAlignment="Left" Margin="0,14,0,0"/>
        </StackPanel>

        <!-- ── Panel: Install ── -->
        <StackPanel Visibility="{Binding IsChecked, ElementName=tabInstall, Converter={StaticResource b2v}}">
          <TextBlock Text="安裝管理" FontSize="18" FontWeight="Bold" Margin="0,0,0,4"/>
          <TextBlock Text="從 GitHub Releases 安裝或更新 CLI 工具（password_recovery_rust.exe）" FontSize="12" Foreground="#64748b" Margin="0,0,0,20"/>
          <Grid Margin="0,0,0,16">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="*"/><ColumnDefinition Width="18"/><ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <StackPanel Grid.Column="0">
              <TextBlock Text="GitHub Repo" FontSize="12" Foreground="#94a3b8" Margin="0,0,0,4"/>
              <TextBox Name="txtInstRepo" Style="{StaticResource Input}"/>
            </StackPanel>
            <StackPanel Grid.Column="2">
              <TextBlock Text="安裝路徑" FontSize="12" Foreground="#94a3b8" Margin="0,0,0,4"/>
              <TextBox Name="txtInstPath" Style="{StaticResource Input}"/>
            </StackPanel>
          </Grid>
          <WrapPanel>
            <Button Name="btnInstall"   Content="安裝" Style="{StaticResource Btn}" Background="#10b981" Margin="0,0,8,0"/>
            <Button Name="btnReinstall" Content="重新安裝" Style="{StaticResource Btn}" Background="#3b82f6" Margin="0,0,8,0"/>
            <Button Name="btnUninstall" Content="移除" Style="{StaticResource Btn}" Background="#ef4444" Margin="0,0,8,0"/>
            <Button Name="btnOpenDir"   Content="開啟目錄" Style="{StaticResource Btn}" Background="#475569"/>
          </WrapPanel>
          <Border Background="#0d1117" CornerRadius="6" Padding="14,10" Margin="0,18,0,0" BorderBrush="#2d3654" BorderThickness="1">
            <TextBlock Name="lblExeStatus" FontSize="12" Foreground="#64748b" TextWrapping="Wrap"/>
          </Border>
        </StackPanel>

        <!-- ── Panel: Settings ── -->
        <StackPanel Visibility="{Binding IsChecked, ElementName=tabSettings, Converter={StaticResource b2v}}">
          <TextBlock Text="工具路徑設定" FontSize="18" FontWeight="Bold" Margin="0,0,0,4"/>
          <TextBlock Text="預設工具路徑會自動填入對應欄位，儲存在本機" FontSize="12" Foreground="#64748b" Margin="0,0,0,20"/>
          <Grid>
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="*"/><ColumnDefinition Width="18"/><ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <Grid.RowDefinitions><RowDefinition/><RowDefinition/><RowDefinition/></Grid.RowDefinitions>
            <StackPanel Grid.Row="0" Grid.Column="0" Margin="0,0,0,14">
              <TextBlock Text="John 工具目錄" FontSize="12" Foreground="#94a3b8" Margin="0,0,0,4"/>
              <TextBox Name="txtSetJohnDir" Style="{StaticResource Input}"/>
            </StackPanel>
            <StackPanel Grid.Row="0" Grid.Column="2" Margin="0,0,0,14">
              <TextBlock Text="john.exe 路徑" FontSize="12" Foreground="#94a3b8" Margin="0,0,0,4"/>
              <TextBox Name="txtSetJohnExe" Style="{StaticResource Input}"/>
            </StackPanel>
            <StackPanel Grid.Row="1" Grid.Column="0" Margin="0,0,0,14">
              <TextBlock Text="hashcat.exe 路徑" FontSize="12" Foreground="#94a3b8" Margin="0,0,0,4"/>
              <TextBox Name="txtSetHcExe" Style="{StaticResource Input}"/>
            </StackPanel>
            <StackPanel Grid.Row="1" Grid.Column="2" Margin="0,0,0,14">
              <TextBlock Text="Perl 路徑" FontSize="12" Foreground="#94a3b8" Margin="0,0,0,4"/>
              <TextBox Name="txtSetPerl" Style="{StaticResource Input}"/>
            </StackPanel>
            <StackPanel Grid.Row="2" Grid.Column="0" Margin="0,0,0,14">
              <TextBlock Text="預設執行緒數" FontSize="12" Foreground="#94a3b8" Margin="0,0,0,4"/>
              <TextBox Name="txtSetThreads" Text="8" Style="{StaticResource Input}"/>
            </StackPanel>
          </Grid>
          <Button Name="btnSaveSettings" Content="儲存設定" Style="{StaticResource Btn}" HorizontalAlignment="Left" Margin="0,6,0,0"/>
          <TextBlock Text="設定儲存在本機，下次開啟時自動載入。" FontSize="11" Foreground="#374151" Margin="0,12,0,0"/>
        </StackPanel>

      </Grid>
    </ScrollViewer>
  </DockPanel>
</Window>
'@

    [xml]$doc = $xaml
    $reader = New-Object System.Xml.XmlNodeReader $doc
    $w = [System.Windows.Markup.XamlReader]::Load($reader)

    # ── Find named elements ──
    function F($n) { $w.FindName($n) }

    $txtLog         = F "txtLog"
    $lblStatus      = F "lblStatus"
    $lblExeStatus   = F "lblExeStatus"
    $txtExtArchive  = F "txtExtArchive"
    $txtExtHashOut  = F "txtExtHashOut"
    $txtExtJohnDir  = F "txtExtJohnDir"
    $txtExtPerl     = F "txtExtPerl"
    $txtJohnHash    = F "txtJohnHash"
    $txtJohnWordlist= F "txtJohnWordlist"
    $txtJohnExe     = F "txtJohnExe"
    $txtHcHash      = F "txtHcHash"
    $txtHcMode      = F "txtHcMode"
    $txtHcAttack    = F "txtHcAttack"
    $txtHcMask      = F "txtHcMask"
    $txtHcWordlist  = F "txtHcWordlist"
    $txtHcExe       = F "txtHcExe"
    $txtQuickArchive= F "txtQuickArchive"
    $txtQuickThreads= F "txtQuickThreads"
    $rbDict         = F "rbDict"
    $txtQuickDict   = F "txtQuickDict"
    $txtQuickMask   = F "txtQuickMask"
    $txtInstRepo    = F "txtInstRepo"
    $txtInstPath    = F "txtInstPath"
    $txtSetJohnDir  = F "txtSetJohnDir"
    $txtSetJohnExe  = F "txtSetJohnExe"
    $txtSetHcExe    = F "txtSetHcExe"
    $txtSetPerl     = F "txtSetPerl"
    $txtSetThreads  = F "txtSetThreads"

    # ── Logging ──
    function Log([string]$msg) {
        $t = Get-Date -Format "HH:mm:ss"
        $txtLog.AppendText("[$t] $msg`n")
        $txtLog.ScrollToEnd()
        [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke(
            [System.Windows.Threading.DispatcherPriority]::Background, [action]{}
        )
    }

    # ── Load settings & apply ──
    $s = Get-CbSettings
    $txtInstRepo.Text = $script:Repo
    $txtInstPath.Text = $script:DefaultInstall

    $propMap = @{
        johnDir   = @($txtSetJohnDir,  $txtExtJohnDir)
        johnExe   = @($txtSetJohnExe,  $txtJohnExe)
        hashcatExe= @($txtSetHcExe,    $txtHcExe)
        perl      = @($txtSetPerl,     $txtExtPerl)
        threads   = @($txtSetThreads,  $txtQuickThreads)
    }

    foreach ($key in $propMap.Keys) {
        if ($s.PSObject.Properties[$key] -and $s.$key) {
            foreach ($el in $propMap[$key]) {
                if (-not $el.Text) { $el.Text = $s.$key }
            }
        }
    }
    if ($s.PSObject.Properties['installPath'] -and $s.installPath) {
        $txtInstPath.Text = $s.installPath
    }

    # ── Update exe status ──
    function RefreshExeStatus {
        $exe = Find-CbExe
        if ($exe) {
            $lblExeStatus.Text = "CLI 工具已安裝: $exe"
            $lblExeStatus.Foreground = [System.Windows.Media.Brushes]::MediumAquamarine
        } else {
            $lblExeStatus.Text = "CLI 工具未安裝。請先安裝再使用提取 Hash / 快速模式。"
            $lblExeStatus.Foreground = [System.Windows.Media.Brushes]::IndianRed
        }
    }
    RefreshExeStatus

    # ── Event: Extract Hash ──
    (F "btnExtract").Add_Click({
        $archive = $txtExtArchive.Text.Trim()
        if (-not $archive) { Log "✗ 請輸入壓縮檔路徑"; return }

        $exe = Find-CbExe
        if (-not $exe) { Log "✗ CLI 工具未安裝，請先到「安裝管理」安裝"; return }

        $cmdArgs = @("extract-hash", "--archive", $archive, "--out", ($txtExtHashOut.Text.Trim()))
        if ($txtExtJohnDir.Text.Trim()) { $cmdArgs += @("--john-dir", $txtExtJohnDir.Text.Trim()) }
        if ($txtExtPerl.Text.Trim())    { $cmdArgs += @("--perl", $txtExtPerl.Text.Trim()) }

        Log "▸ 提取 Hash..."
        try {
            $result = & $exe @cmdArgs 2>&1 | Out-String
            Log $result.Trim()

            if ($result -match "hash_file:\s*(.+)") {
                $hf = $Matches[1].Trim()
                if (-not $txtJohnHash.Text) { $txtJohnHash.Text = $hf }
                if (-not $txtHcHash.Text)   { $txtHcHash.Text = $hf }
                Log "✓ Hash 路徑已自動填入 John / Hashcat 面板"
            }
        } catch {
            Log "✗ $($_.Exception.Message)"
        }
    })

    # ── Event: John Crack ──
    (F "btnJohn").Add_Click({
        $hashFile = $txtJohnHash.Text.Trim()
        if (-not $hashFile) { Log "✗ 請輸入 Hash 檔案路徑"; return }

        $exe = Find-CbExe
        if (-not $exe) { Log "✗ CLI 工具未安裝"; return }

        $cmdArgs = @("john-crack", "--hash-file", $hashFile)
        if ($txtJohnWordlist.Text.Trim()) { $cmdArgs += @("--wordlist", $txtJohnWordlist.Text.Trim()) }
        if ($txtJohnExe.Text.Trim())      { $cmdArgs += @("--john", $txtJohnExe.Text.Trim()) }

        Log "▸ 啟動 John the Ripper（新視窗）..."
        try {
            Start-Process -FilePath $exe -ArgumentList $cmdArgs
            Log "✓ John 已在獨立視窗中執行"
        } catch {
            Log "✗ $($_.Exception.Message)"
        }
    })

    # ── Event: Hashcat GPU ──
    (F "btnHashcat").Add_Click({
        $hashFile = $txtHcHash.Text.Trim()
        if (-not $hashFile) { Log "✗ 請輸入 Hash 檔案路徑"; return }

        $exe = Find-CbExe
        if (-not $exe) { Log "✗ CLI 工具未安裝"; return }

        $cmdArgs = @("hashcat-crack", "--hash-file", $hashFile, "--mode", $txtHcMode.Text.Trim(), "--attack", $txtHcAttack.Text.Trim())
        if ($txtHcMask.Text.Trim())     { $cmdArgs += @("--mask", $txtHcMask.Text.Trim()) }
        if ($txtHcWordlist.Text.Trim()) { $cmdArgs += @("--wordlist", $txtHcWordlist.Text.Trim()) }
        if ($txtHcExe.Text.Trim())      { $cmdArgs += @("--hashcat", $txtHcExe.Text.Trim()) }

        Log "▸ 啟動 Hashcat GPU（新視窗）..."
        try {
            Start-Process -FilePath $exe -ArgumentList $cmdArgs
            Log "✓ Hashcat 已在獨立視窗中執行"
        } catch {
            Log "✗ $($_.Exception.Message)"
        }
    })

    # ── Event: Quick Mode (async via DispatcherTimer) ──
    $script:_qProc = $null
    (F "btnQuick").Add_Click({
        if ($null -ne $script:_qProc -and -not $script:_qProc.HasExited) {
            Log "⚠ 快速模式仍在執行中"; return
        }

        $archive = $txtQuickArchive.Text.Trim()
        if (-not $archive) { Log "✗ 請輸入壓縮檔路徑"; return }

        $exe = Find-CbExe
        if (-not $exe) { Log "✗ CLI 工具未安裝"; return }

        $threads = $txtQuickThreads.Text.Trim()
        if (-not $threads) { $threads = "8" }

        if ($rbDict.IsChecked) {
            $dict = $txtQuickDict.Text.Trim()
            if (-not $dict) { Log "✗ 請輸入字典檔路徑"; return }
            $cmdArgs = @("recover", "--archive", $archive, "--dict", $dict, "--threads", $threads)
        } else {
            $mask = $txtQuickMask.Text.Trim()
            if (-not $mask) { Log "✗ 請輸入 Mask"; return }
            $cmdArgs = @("recover", "--archive", $archive, "--mask", $mask, "--threads", $threads)
        }

        Log "▸ 快速模式執行中..."
        $lblStatus.Text = "● 執行中..."
        $lblStatus.Foreground = [System.Windows.Media.Brushes]::Gold
        (F "btnQuick").IsEnabled = $false

        try {
            $script:_qTmpOut = [System.IO.Path]::GetTempFileName()
            $script:_qTmpErr = [System.IO.Path]::GetTempFileName()
            $script:_qProc = Start-Process -FilePath $exe -ArgumentList $cmdArgs -NoNewWindow -PassThru `
                              -RedirectStandardOutput $script:_qTmpOut -RedirectStandardError $script:_qTmpErr

            $script:_qTimer = New-Object System.Windows.Threading.DispatcherTimer
            $script:_qTimer.Interval = [TimeSpan]::FromSeconds(1)
            $script:_qTimer.Add_Tick({
                if ($null -eq $script:_qProc -or -not $script:_qProc.HasExited) { return }
                $script:_qTimer.Stop()

                $so = ""; $se = ""
                if (Test-Path $script:_qTmpOut) { $so = (Get-Content $script:_qTmpOut -Raw -ErrorAction SilentlyContinue) }
                if (Test-Path $script:_qTmpErr) { $se = (Get-Content $script:_qTmpErr -Raw -ErrorAction SilentlyContinue) }
                Remove-Item $script:_qTmpOut, $script:_qTmpErr -Force -ErrorAction SilentlyContinue

                if ($so) { Log $so.Trim() }
                if ($se) { Log ("⚠ " + $se.Trim()) }

                if ($so -match "password:\s*(.+)") {
                    $foundPwd = $Matches[1].Trim()
                    Log ("✓ 密碼已找到: " + $foundPwd)
                    [System.Windows.Clipboard]::SetText($foundPwd)
                    Log "✓ 已複製到剪貼簿"
                    [System.Windows.MessageBox]::Show(
                        ("密碼: " + $foundPwd),
                        "密碼已找到",
                        [System.Windows.MessageBoxButton]::OK,
                        [System.Windows.MessageBoxImage]::Information
                    ) | Out-Null
                } elseif ($so -match "not_found") {
                    Log "⚠ 字典/Mask 搜尋完畢，未找到密碼"
                }

                $script:_qProc = $null
                $lblStatus.Text = "● 就緒"
                $lblStatus.Foreground = [System.Windows.Media.Brushes]::MediumAquamarine
                (F "btnQuick").IsEnabled = $true
            })
            $script:_qTimer.Start()
        } catch {
            Log ("✗ " + $_.Exception.Message)
            $lblStatus.Text = "● 就緒"
            $lblStatus.Foreground = [System.Windows.Media.Brushes]::MediumAquamarine
            (F "btnQuick").IsEnabled = $true
        }
    })

    # ── Event: Install ──
    (F "btnInstall").Add_Click({
        $repo = $txtInstRepo.Text.Trim()
        $path = $txtInstPath.Text.Trim()
        if (-not $repo -or -not $path) { Log "✗ 請填寫 Repo 和安裝路徑"; return }

        if (Test-Path $path) { Log "✗ 安裝路徑已存在: $path（請使用重新安裝）"; return }

        Log "▸ 安裝中..."
        try {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
            $api = "https://api.github.com/repos/$repo/releases/latest"
            Log "▸ 查詢最新版本..."
            $release = Invoke-RestMethod -Uri $api
            $asset = $release.assets | Where-Object { $_.name -match "windows" -and $_.name -match "x64" -and $_.name -match "\.zip$" } | Select-Object -First 1
            if (-not $asset) { Log "✗ 找不到 Windows x64 zip 資產"; return }

            $zip = Join-Path $env:TEMP "prr_latest.zip"
            Log "▸ 下載: $($asset.browser_download_url)"
            Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip
            Log "▸ 解壓縮..."
            Expand-Archive -Path $zip -DestinationPath $path -Force
            Remove-Item $zip -Force
            Log "✓ 安裝完成: $path"
            RefreshExeStatus
        } catch {
            Log "✗ $($_.Exception.Message)"
        }
    })

    # ── Event: Reinstall ──
    (F "btnReinstall").Add_Click({
        $repo = $txtInstRepo.Text.Trim()
        $path = $txtInstPath.Text.Trim()
        if (-not $repo -or -not $path) { Log "✗ 請填寫 Repo 和安裝路徑"; return }

        Log "▸ 重新安裝中..."
        try {
            if (Test-Path $path) { Remove-Item $path -Recurse -Force; Log "▸ 已移除舊安裝" }
            New-Item -ItemType Directory -Path $path -Force | Out-Null
            $api = "https://api.github.com/repos/$repo/releases/latest"
            $release = Invoke-RestMethod -Uri $api
            $asset = $release.assets | Where-Object { $_.name -match "windows" -and $_.name -match "x64" -and $_.name -match "\.zip$" } | Select-Object -First 1
            if (-not $asset) { Log "✗ 找不到資產"; return }

            $zip = Join-Path $env:TEMP "prr_latest.zip"
            Log "▸ 下載..."
            Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip
            Expand-Archive -Path $zip -DestinationPath $path -Force
            Remove-Item $zip -Force
            Log "✓ 重新安裝完成"
            RefreshExeStatus
        } catch {
            Log "✗ $($_.Exception.Message)"
        }
    })

    # ── Event: Uninstall ──
    (F "btnUninstall").Add_Click({
        $path = $txtInstPath.Text.Trim()
        if (-not $path) { Log "✗ 安裝路徑為空"; return }

        if (Test-Path $path) {
            Remove-Item $path -Recurse -Force
            Log "✓ 已移除: $path"
        } else {
            Log "⚠ 路徑不存在: $path"
        }
        RefreshExeStatus
    })

    # ── Event: Open Directory ──
    (F "btnOpenDir").Add_Click({
        $path = $txtInstPath.Text.Trim()
        if ($path -and (Test-Path $path)) {
            Start-Process explorer.exe $path
        } else {
            Log "⚠ 目錄不存在: $path"
        }
    })

    # ── Event: Save Settings ──
    (F "btnSaveSettings").Add_Click({
        $obj = [PSCustomObject]@{
            johnDir    = $txtSetJohnDir.Text.Trim()
            johnExe    = $txtSetJohnExe.Text.Trim()
            hashcatExe = $txtSetHcExe.Text.Trim()
            perl       = $txtSetPerl.Text.Trim()
            threads    = $txtSetThreads.Text.Trim()
            installPath= $txtInstPath.Text.Trim()
        }
        Save-CbSettings $obj

        if ($obj.johnDir -and -not $txtExtJohnDir.Text) { $txtExtJohnDir.Text = $obj.johnDir }
        if ($obj.johnExe -and -not $txtJohnExe.Text)    { $txtJohnExe.Text = $obj.johnExe }
        if ($obj.hashcatExe -and -not $txtHcExe.Text)   { $txtHcExe.Text = $obj.hashcatExe }
        if ($obj.perl -and -not $txtExtPerl.Text)        { $txtExtPerl.Text = $obj.perl }

        Log "✓ 設定已儲存"
    })

    # ── Event: Log actions ──
    (F "btnCopyLog").Add_Click({
        if ($txtLog.Text) {
            [System.Windows.Clipboard]::SetText($txtLog.Text)
            Log "✓ 日誌已複製到剪貼簿"
        }
    })

    (F "btnClearLog").Add_Click({
        $txtLog.Clear()
        Log "日誌已清除"
    })

    # ── Ready ──
    Log "✓ CipherBreak 介面已就緒"
    $w.ShowDialog() | Out-Null
}

# ══════════════════════════════════════════
#  Entry
# ══════════════════════════════════════════
if ($MyInvocation.InvocationName -ne ".") {
    try {
        $relaunched = Ensure-Sta
        if (-not $relaunched) {
            Show-CipherBreak
        }
    } catch {
        Write-Error $_
    }
}
