# 開發指南

## 建立新模組

### 步驟 1：複製模板
```bash
cp -r modules/template modules/my-new-tool
```

### 步驟 2：編輯 module.json
```json
{
  "name": "my-new-tool",
  "display_name": "我的新工具",
  "version": "1.0.0",
  "description": "工具描述",
  "author": "你的名字",
  "category": "utility",
  "requires_admin": false
}
```

### 步驟 3：實作 main.ps1
```powershell
# 載入共用工具
. "$PSScriptRoot\..\..\shared\utils.ps1"

function Start-MyTool {
    Write-Info "工具啟動"

    # 你的邏輯

    Write-Success "完成"
}

Start-MyTool
```

## 可用的共用函數

### UI 函數
- `Show-MessageBox($Message, $Title, $Type)` - 訊息框
- `Show-FileDialog($Title, $Filter, -Save)` - 檔案選擇
- `Show-FolderDialog($Description)` - 資料夾選擇
- `Write-Success($Message)` - 綠色成功訊息
- `Write-Error($Message)` - 紅色錯誤訊息
- `Write-Warning($Message)` - 黃色警告訊息
- `Write-Info($Message)` - 藍色資訊訊息

### 工具函數
- `Test-Administrator()` - 檢查管理員權限
- `Get-FileHash256($FilePath)` - 計算 SHA256
- `Get-RandomString($Length, -AlphaNumericOnly)` - 隨機字串
- `Write-Log($Message, $Level, $LogFile)` - 寫入日誌
- `Invoke-WithRetry($ScriptBlock, $MaxRetries, $DelaySeconds)` - 重試機制

## 模組類別建議

- `utility` - 通用工具
- `file` - 檔案處理
- `network` - 網路工具
- `system` - 系統管理
- `security` - 安全工具
- `development` - 開發輔助
- `media` - 媒體處理
- `data` - 資料處理

## 最佳實踐

1. **錯誤處理**：使用 try-catch 包裝可能失敗的操作
2. **使用者回饋**：提供清晰的進度和結果訊息
3. **參數驗證**：檢查使用者輸入的有效性
4. **文件完整**：在 README.md 中說明功能和使用方式
5. **模組化**：將複雜功能拆分成多個函數

## 測試模組

```powershell
# 直接啟動特定模組
.\launcher.ps1 -ModuleName "my-new-tool"
```

## 發布模組

1. 確保 module.json 資訊完整
2. 撰寫 README.md 說明文件
3. 測試所有功能正常運作
4. 提交到 Git 儲存庫
