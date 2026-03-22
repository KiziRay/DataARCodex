@echo off
chcp 65001 >nul
echo ═══════════════════════════════════════════════════════════════
echo   Community Toolkit - 快速啟動
echo ═══════════════════════════════════════════════════════════════
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0launcher.ps1"
pause
