SET IP=192.168.3.12
SET PW=
SET RA=16/11
SET ZM=1

SET CMD="Import-Module %~dp0rdpConnect.ps1; rdpConnect %IP% %PW% -Ratio:(%RA%) -Zoom:%ZM%"

C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -Command "&{%CMD%}"
