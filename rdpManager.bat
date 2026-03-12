@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -Command ^
    "Set-Location '%~dp0'; Import-Module '.\RdpConnect.psd1'; Show-RdpManager"
exit /b %ERRORLEVEL%
