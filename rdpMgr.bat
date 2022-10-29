@echo off

set "0=%~f0"& set "1=%~dp0"& set PwshScript=([Io.File]::ReadAllText($env:0,[Text.Encoding]::Default) -split '[:]PwshScript')
powershell -nop "(%PwshScript%[2])|iex; Exit $LastExitCode"

@REM echo ExitCode: %errorlevel%& pause
Exit %errorlevel%





:PwshScript#:: script1:: Main
#:: --------------------------------------------------------------------------------------------------------------------------------
Write-Host "by PSVersion::" $PSVersionTable.PSVersion

$CsvPath  = '.\rdpList.csv'
$Encoding = 65001
$Ratio    = (16/10)

rdpMgr -Path:$CsvPath -Encoding:$Encoding -Ratio:$Ratio


:PwshScript#:: script2:: Prerequisite
#:: --------------------------------------------------------------------------------------------------------------------------------
# Load Setting
Set-Location ($env:1); [IO.Directory]::SetCurrentDirectory(((Get-Location -PSProvider FileSystem).ProviderPath))
irm 'raw.githubusercontent.com/hunandy14/rdpConnect/master/rdpConnect.ps1'|iex
(([Io.File]::ReadAllText($env:0,[Text.Encoding]::Default) -split '[:]PwshScript')[1])|iex


:PwshScript#:: script3:: rdpTemplate File
#:: --------------------------------------------------------------------------------------------------------------------------------
screen mode id:i:1
use multimon:i:0
desktopwidth:i:${width}
desktopheight:i:${height}
session bpp:i:32
winposstr:s:0,1,${x1},${y1},${x2},${y2}
compression:i:1
keyboardhook:i:2
audiocapturemode:i:0
videoplaybackmode:i:1
connection type:i:7
networkautodetect:i:1
bandwidthautodetect:i:1
displayconnectionbar:i:1
enableworkspacereconnect:i:0
disable wallpaper:i:0
allow font smoothing:i:0
allow desktop composition:i:0
disable full window drag:i:1
disable menu anims:i:1
disable themes:i:0
disable cursor setting:i:0
bitmapcachepersistenable:i:1
full address:s:${ip}
audiomode:i:0
redirectprinters:i:1
redirectcomports:i:0
redirectsmartcards:i:1
redirectclipboard:i:1
redirectposdevices:i:0
autoreconnection enabled:i:1
authentication level:i:2
prompt for credentials:i:0
negotiate security layer:i:1
remoteapplicationmode:i:0
alternate shell:s:
shell working directory:s:
gatewayhostname:s:
gatewayusagemethod:i:4
gatewaycredentialssource:i:4
gatewayprofileusagemethod:i:0
promptcredentialonce:i:0
gatewaybrokeringtype:i:0
use redirection server name:i:0
rdgiskdcproxy:i:0
kdcproxyname:s:
drivestoredirect:s:
