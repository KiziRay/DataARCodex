# 模組模板

這是一個模組模板，用於快速建立新模組。

## 建立新模組

1. 複製整個 `template` 目錄
2. 重新命名為你的模組名稱（例如：`my-tool`）
3. 編輯 `module.json`：
   - 修改 `name`（模組內部名稱，使用小寫和連字號）
   - 修改 `display_name`（顯示名稱）
   - 修改 `description`（模組描述）
   - 修改 `author`（作者名稱）
   - 根據需要調整其他設定
4. 編輯 `main.ps1` 實作你的功能
5. 重新啟動 launcher.ps1 即可看到新模組

## 模組結構

```
my-module/
├── module.json    # 模組設定檔（必須）
├── main.ps1       # 主要邏輯（必須）
├── README.md      # 說明文件（建議）
└── assets/        # 資源檔案（可選）
```

## 可用的共用函數

模組可以使用以下共用函數：

### UI 函數（來自 core/ui-framework.ps1）
- `Show-MessageBox` - 顯示訊息框
- `Show-FileDialog` - 檔案選擇對話框
- `Show-FolderDialog` - 資料夾選擇對話框
- `Write-Success` - 顯示成功訊息
- `Write-Error` - 顯示錯誤訊息
- `Write-Warning` - 顯示警告訊息
- `Write-Info` - 顯示資訊訊息

### 工具函數（來自 shared/utils.ps1）
- `Test-Administrator` - 檢查是否為管理員
- `Get-FileHash256` - 計算檔案 SHA256
- `Write-Log` - 寫入日誌
- `Invoke-WithRetry` - 重試機制
- `Get-RandomString` - 產生隨機字串

## 範例

參考 `modules/example/` 目錄中的範例模組。
