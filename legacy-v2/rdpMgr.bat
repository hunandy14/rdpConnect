@echo off
chcp 65001 >NUL
set "ScriptDir=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -Command ". '%ScriptDir%rdpConnect.ps1'; rdpMgr -Path:'%ScriptDir%rdpList.csv' -Encoding:65001 -Ratio:(16/10); Exit $LastExitCode"
Exit %errorlevel%
