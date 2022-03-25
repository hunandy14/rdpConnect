SET IP="192.168.1.1"
SET PW="pw"

: Online
SET CMD="&{irm bit.ly/36tr1aS|iex; rdpConnect %IP% %PW%}"
: Offline
: SET CMD="&{Import-Module %~dp0rdpConnect\rdpConnect.ps1; rdpConnect %IP% %PW%}

"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -Command %CMD%
