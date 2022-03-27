SET IP="192.168.3.12"
SET PW="123456"
SET ZM=1.0
SET RA=(16/11)

: Online
SET CMD1="&{Import-Module %~dp0rdpConnect.ps1; rdpConnect %IP% %PW% -Ratio:%RA% -Zoom:%ZM%}"
: Offline
SET CMD2="&{Import-Module %~dp0rdpConnect\rdpConnect.ps1; rdpConnect %IP% %PW% -Ratio:%RA% -Zoom:%ZM%}

"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -Command %CMD2%
