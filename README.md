# Community Toolkit

模組化社群工具包 - 可擴展的工具集合平台

## 專案結構

```
community-toolkit/
├── launcher.ps1          # 主啟動器
├── config.json           # 全域設定
├── modules/              # 功能模組目錄
│   ├── example/         # 範例模組
│   └── template/        # 模組模板
├── core/                 # 核心框架
│   ├── module-loader.ps1
│   └── ui-framework.ps1
└── shared/              # 共用資源
    └── utils.ps1
```

## 快速開始

1. 執行 `launcher.ps1` 啟動工具包
2. 選擇要使用的模組
3. 按照模組指示操作

## 新增模組

1. 複製 `modules/template/` 目錄
2. 重新命名為你的模組名稱
3. 編輯 `module.json` 設定模組資訊
4. 實作 `main.ps1` 中的功能邏輯
5. 重新啟動 launcher 即可看到新模組

## 模組開發規範

每個模組必須包含：
- `module.json` - 模組元資料
- `main.ps1` - 主要邏輯
- `README.md` - 模組說明文件

## 技術棧

- PowerShell 7+ (核心框架)
- WPF (圖形介面)
- JSON (設定檔)

## 授權

MIT License
