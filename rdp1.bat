SET IP=192.168.1.1
SET PW=pw
pwsh -Command "&{irm bit.ly/36tr1aS|iex; rdpConnect %IP% %PW%}"
: pwsh -Command "&{Import-Module %~dp0rdpConnect\rdpConnect.ps1; rdpConnect %IP% %PW%}
