function rdpConnect {
    [CmdletBinding(DefaultParameterSetName = "A")]
    param (
        [Parameter(Mandatory, Position = 0, ParameterSetName = "")]
        [string] $IP,
        [Parameter(Position = 1, ParameterSetName = "A")]
        [Parameter(Position = 1, ParameterSetName = "B")]
        [Parameter(Position = 1, ParameterSetName = "C")]
        [Parameter(ParameterSetName = "D")]
        [String] $PasswordCopy,
        # 傻瓜包
        [Parameter(ParameterSetName = "A")]
        [double] $Ratio = 16/11,
        [Parameter(ParameterSetName = "A")] # 預設模式
        [switch] $Nomal,
        [Parameter(ParameterSetName = "B")] # 可選1 (最大化視窗)
        [switch] $MaxWindows,
        [Parameter(ParameterSetName = "C")] # 可選2 (螢幕)
        [switch] $FullScreen,
        [Parameter(ParameterSetName = "D")] # 可選3 (自動解析度與位置)
        [switch] $Define,
        # 自訂模式
        [Parameter(Position = 1, ParameterSetName = "D")]
        [int64] $device_w = 0,
        [Parameter(Position = 2, ParameterSetName = "D")]
        [int64] $device_h = 0,
        [Parameter(Position = 3, ParameterSetName = "D")]
        [int64] $x1 = 0,
        [Parameter(Position = 4, ParameterSetName = "D")]
        [int64] $y1 = 0,
        # 螢幕縮放
        [Parameter(ParameterSetName = "")]
        [double] $Zoom = 1.0,
        # 輸出rdp檔案
        [Parameter(ParameterSetName = "A")]
        [String] $OutputRDP
    )
    # 獲取當前位置
    if ($PSScriptRoot) { $curDir = $PSScriptRoot } else { $curDir = (Get-Location).Path }
    # 獲取螢幕解析度
    Add-Type -AssemblyName System.Windows.Forms

    # 設置參數
    [string] $ip      = $IP
    [double] $width   = $Zoom * [System.Windows.Forms.SystemInformation]::PrimaryMonitorSize.width
    [double] $height  = $Zoom * [System.Windows.Forms.SystemInformation]::PrimaryMonitorSize.height
    # [int64] $x1      = 0
    # [int64] $y1      = 0

    # 獲取樣板文件
    $template_path1 = "$curDir\Template.rdp"
    $template_path2 = "$env:TEMP\Template.rdp"
    if (Test-Path $template_path1 -PathType:Leaf) {
        $rdp = Get-Content $template_path1
    } elseif (Test-Path $template_path2 -PathType:Leaf) {
        $rdp = Get-Content $template_path2
    } else {
        $rdp = Invoke-RestMethod 'raw.githubusercontent.com/hunandy14/rdpConnect/master/Template.rdp'
        Set-Content $template_path2 $rdp
    }


    # 選擇模式
    if ($FullScreen) {
        # 設置 rdp 檔案
        $rdp = $rdp.Replace('${ip}'     ,$ip)
        $rdp = $rdp.Replace('${width}'  ,$width)
        $rdp = $rdp.Replace('${height}' ,$height)
        $rdp = $rdp.Replace('${x1}'     ,$x1)
        $rdp = $rdp.Replace('${y1}'     ,$y1)
        $rdp = $rdp.Replace('${x2}'     ,$width)
        $rdp = $rdp.Replace('${y2}'     ,$height)
        # 全螢幕參數
        $rdp = $rdp.Replace('screen mode id:i:1', 'screen mode id:i:2')
        $rdp = $rdp.Replace('connection type:i:7', 'connection type:i:3')
        $rdp = $rdp.Replace('authentication level:i:2', 'authentication level:i:0')
    } else {
        # 設置參數
        [double] $margin1    = $Zoom*7
        [double] $margin2    = $Zoom*14 +2.0
        $margin1 = [Math]::Round($margin1, 0, [MidpointRounding]::AwayFromZero)
        $margin2 = [Math]::Round($margin2, 0, [MidpointRounding]::AwayFromZero)

        [int64] $title_h    = $Zoom *30.0
        [int64] $star_h     = $Zoom *40.0
        [int64] $width_max  = $width - $margin2
        [int64] $height_max = $height - ($title_h+$star_h + $margin2)

        # 遠端裝置解析度
        if ($device_w -eq 0) { $device_w = $width_max }
        if ($device_h -eq 0) { $device_h = $height_max }
        # $width_max
        # $height_max
        [int64] $x2 = $x1+$device_w +$margin2
        [int64] $y2 = $y1+$device_h +$margin2 + $title_h
        # 設定模式
        $Nomal = $true
        if ($MaxWindows -or $Define) {$Nomal = $false}
        if ($Nomal) {
            $new_w = $device_h*$Ratio
            $x1 = $device_w - $new_w
            $device_w = $new_w
        }
        # 檢查是否超過螢幕
        $device_x_max = $width
        $device_y_max = $height-$star_h
        if ($device_w -gt $width_max) { $device_w = $width_max }
        if ($device_h -gt $height_max) { $device_h = $height_max }
        if ($x2 -gt $device_x_max) { $x2 = $device_x_max }
        if ($y2 -gt $device_y_max) { $y2 = $device_y_max }
        # 設置 rdp 檔案
        $rdp = $rdp.Replace('${ip}'     ,$ip)
        $rdp = $rdp.Replace('${width}'  ,$device_w)
        $rdp = $rdp.Replace('${height}' ,$device_h)
        $rdp = $rdp.Replace('${x1}'     ,$x1)
        $rdp = $rdp.Replace('${y1}'     ,$y1 + $margin1)
        $rdp = $rdp.Replace('${x2}'     ,$x2)
        $rdp = $rdp.Replace('${y2}'     ,$y2)
    }

    # 儲存 rdp 檔案並開啟
    $rdp_path = "$env:TEMP\Default.rdp"
    if ($OutputRDP) { $rdp_path = $OutputRDP }
    if($PasswordCopy) {
        if ((Get-Clipboard) -ne $PasswordCopy) { Set-Clipboard $PasswordCopy }
    }
    Set-Content $rdp_path $rdp
    if (!$OutputRDP){ Start-Process $rdp_path }
}
# rdpConnect 192.168.3.12 -Zoom:1.5
# rdpConnect 192.168.3.12 'pwcopy' -Zoom:1.5
# rdpConnect 192.168.3.12 -Ratio:1.1 -Zoom:1.5
# rdpConnect 192.168.3.12 -FullScreen -Zoom:1.5
# rdpConnect 192.168.3.12 -MaxWindows -Zoom:1.5
# rdpConnect 192.168.3.12 -Define 1024 768 100 100 -Zoom:1.5


function Install {
    param (
        [switch] $ForceAppend
    )
    # 創建[啟動文件]
    if (!(Test-Path -Path $PROFILE )) {
        New-Item -Type File -Path $PROFILE -Force
    } $Dir = (Get-Item $PROFILE).Directory

    # 下載ps1到[啟動文件]
    $URL  = "raw.githubusercontent.com/hunandy14/rdpConnect/master/rdpConnect.ps1"
    $File = "$Dir\rdpConnect.ps1"
    Invoke-WebRequest $URL -OutFile:$File

    # 寫入[啟動文件]
    $impt = "Import-Module rdpConnect.ps1"
    if ($ForceAppend) {
        if (!((Get-Content $PROFILE)|Where-Object{$_ -eq $impt})) { Add-Content $PROFILE "`n$impt" }
        Write-Host "已新增 Import-Module 到啟動文件結尾" -ForegroundColor:Yellow
    } else {
        Set-Clipboard $impt
        notepad.exe $PROFILE
    }
} # Install


function Download {
    param (
        [Parameter(Position = 0, ParameterSetName = "")]
        [string] $IP = '192.168.1.1',
        [Parameter(Position = 1, ParameterSetName = "")]
        [string] $PW = '',
        [Parameter(ParameterSetName = "")]
        [string] $Ratio = '16.0/11.0',
        [Parameter(ParameterSetName = "")]
        [string] $Zoom = '1.0',
        [Parameter(ParameterSetName = "")]
        [string] $OutName = "rdpServer1",
        [Parameter(ParameterSetName = "")]
        [switch] $Pwsh7
    )
    # Pswh版本
    $Pwsh_Path = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" 
    if ($Pwsh7) { $Pwsh_Path = "C:\Program Files\PowerShell\7\pwsh.exe" }
    # 載入函式
    (Invoke-RestMethod 'raw.githubusercontent.com/hunandy14/cvEncode/master/cvEncoding.ps1')|Invoke-Expression;
    $en = (C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -Command '&{[Text.Encoding]::Default.WindowsCodePage}')
    # 下載離線包
    (Invoke-RestMethod 'raw.githubusercontent.com/hunandy14/rdpConnect/master/rdpConnect.ps1')|WriteContent 'rdpConnect\rdpConnect.ps1' -Encoding:$en
    (Invoke-RestMethod 'raw.githubusercontent.com/hunandy14/rdpConnect/master/Template.rdp')|WriteContent 'rdpConnect\Template.rdp' -Encoding:$en
    
    # BAT檔案內容
    $ct = "SET IP=$IP
SET PW=$PW
SET RA=$Ratio
SET ZM=$Zoom

SET CMD=`"Import-Module %~dp0rdpConnect\rdpConnect.ps1; rdpConnect %IP% %PW% -Ratio:(%RA%) -Zoom:%ZM%`"

`"$Pwsh_Path`" -Command `"&{%CMD%}`""
    
    # 輸出BAT檔案
    $ct|WriteContent "$OutName.bat" -Encoding:$en
} # Download '192.168.3.12' '123456' -Ratio:(16/11) -Zoom:1.5

