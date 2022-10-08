# 獲取螢幕解析度
$__GetScreenInfoFlag__
function GetScreenInfo {
    if (!$__GetScreenInfoFlag__) {
    Add-Type -TypeDefinition:@"
using System;
using System.Runtime.InteropServices;
public class PInvoke {
    [DllImport("user32.dll")] public static extern IntPtr GetDC(IntPtr hwnd);
    [DllImport("gdi32.dll")] public static extern int GetDeviceCaps(IntPtr hdc, int nIndex);
}
"@
    } $__GetScreenInfoFlag__ = $true
    
    $hdc = [PInvoke]::GetDC([IntPtr]::Zero)
    $Width   = [PInvoke]::GetDeviceCaps($hdc, 118)
    $Height  = [PInvoke]::GetDeviceCaps($hdc, 117)
    $Refresh = [PInvoke]::GetDeviceCaps($hdc, 116)
    $Scaling = [PInvoke]::GetDeviceCaps($hdc, 117) / [PInvoke]::GetDeviceCaps($hdc, 10)
    $LogicalHeight =  [PInvoke]::GetDeviceCaps($hdc, 10)
    $LogicalWeight =  [PInvoke]::GetDeviceCaps($hdc, 8)
   
    [pscustomobject]@{
        Width         = $Width
        Height        = $Height
        Refresh       = $Refresh
        # Scaling       = [Math]::Round($Scaling, 3)
        Scaling       = $Scaling
        LogicalHeight = $LogicalHeight
        LogicalWeight = $LogicalWeight
    }
} $ScreenInfo = GetScreenInfo


# RDP結構
function New-RdpInfo {
    param (
        [string] $ip ='127.0.0.1',
        [string] $device_w=0,
        [string] $device_h=0,
        [string] $x1=0,
        [string] $y1=0,
        [string] $x2=0,
        [string] $y2=0
    )
    [pscustomobject]@{
        Ip         = $ip
        Resolution = @($device_w,$device_h)
        Winposstr  = @($x1, $y1, $x2, $y2)
        Margin     = @(0, 0)
        Path       = ''
    }
} # New-RdpInfo
# 轉換至RDP檔案
function ConvertTo-Rdp {
    param (
        [Parameter(Position = 0, ParameterSetName = "")]
        [string] $Template = 'Template.rdp',
        [Parameter(ValueFromPipeline, ParameterSetName = "")]
        [System.Object] $InputObject
    )
    $rdp = Get-Content $Template
    $rdp = $rdp.Replace('${ip}'     ,$InputObject.Ip)
    $rdp = $rdp.Replace('${width}'  ,$InputObject.Resolution[0])
    $rdp = $rdp.Replace('${height}' ,$InputObject.Resolution[1])
    $rdp = $rdp.Replace('${x1}'     ,$InputObject.Winposstr[0])
    $rdp = $rdp.Replace('${y1}'     ,$InputObject.Winposstr[1])
    $rdp = $rdp.Replace('${x2}'     ,$InputObject.Winposstr[2])
    $rdp = $rdp.Replace('${y2}'     ,$InputObject.Winposstr[3])
    return $rdp
}
# $rdp_path = 'run.rdp'
# $rdp=(New-RdpInfo '192.168.3.12' 2543 1494 0 10 2560 1550)
# $rdp|ConvertTo-Rdp|Set-Content $rdp_path
# Start-Process $rdp_path
# RETURN

# 取到最近偶數 (遠離零 ex: 13.0 -> 14)
function RoundToEven {
    param (
        [Double] $Decimal
    )
    [Double] $result = [Math]::Round(($Decimal), 0, [MidpointRounding]::ToEven)
    if ($result%2 -ne 0) {
        # 偏移量基數 (這裡0已經排除了不會出現)
        if ($Decimal -gt 0) { $shift=1 } elseif ($Decimal -lt 0) { $shift=-1 }
        # 遠離0的偏移量
        $diff=($result-$Decimal)*$shift
        # 補償成偶數
        if ($diff -gt 0) { $result = $result-$shift }
        elseif ($diff -le 0) { $result = $result+$shift }
    } return $result
} # RoundToEven 11
# 捨去到偶數
function FloorToEven {
    param (
        [Double] $Decimal
    )
    # 偏移量基數
    if ($Decimal -gt 0) { $shift=1 } elseif ($Decimal -lt 0) { $shift=-1 } else { $shift=0 }
    return (RoundToEven ($Decimal-$shift))
}
# 計算最大化的視窗數值
function rdpMaxSize {
    param (
        [String] $Width,
        [String] $Height,
        [double] $Scaling=1.0
    )
    # 初始數據
    $star   = 40
    $title  = (30-2)
    $margin = 7
    # 縮放後取到偶數
    $margin2 = [Math]::Round(($Scaling*$margin), 0, [MidpointRounding]::ToEven)
    $title2  = [Math]::Round(($Scaling*$title ), 0, [MidpointRounding]::ToEven)
    $star2   = [Math]::Round(($Scaling*$star  ), 0, [MidpointRounding]::ToEven)
    # 計算實際邊緣寬度
    $mgW = $margin2+$margin2+1
    $mgH = $title2+2+$margin2+2
    $mgW = [Math]::Round(($mgW+0.5), 0, [MidpointRounding]::ToEven)
    $mgH = [Math]::Round(($mgH+0.5), 0, [MidpointRounding]::ToEven)
    # 輸出視窗範圍
    $x2 = $Width
    $y2 = $Height - $star2
    $x1 = 0
    $y1 = [Math]::Round(($margin2+0.5), 0, [MidpointRounding]::ToEven)
    # 計算解度
    $w = $x2-$x1-$mgW
    $h = $y2-$y1-$mgH
    $w = [Math]::Round(($w-0.5), 0, [MidpointRounding]::ToEven)
    $h = [Math]::Round(($h-0.5), 0, [MidpointRounding]::ToEven)
    $rdp = New-RdpInfo '' $w $h $x1 $y1 $x2 $y2
    $rdp.Margin[0] = $mgW
    $rdp.Margin[1] = $mgH
    return $rdp
} 
# $rdp_path = 'run.rdp'
# $rdpInfo = rdpMaxSize $ScreenInfo.Width $ScreenInfo.Height 1.25
# $rdpInfo.Ip = '192.168.3.12'
# $rdpInfo
# $rdp = $rdpInfo|ConvertTo-Rdp $rdp_path
# Start-Process $rdp_path
# RETURN

# 連接到rdp遠端
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
    [double] $Zoom = $ScreenInfo.Scaling

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
    
    # 計算最大化的視窗數值
    $rdpInfo = rdpMaxSize $ScreenInfo.Width $ScreenInfo.Height $ScreenInfo.Scaling
    $rdpInfo.Ip = $IP
    $rdpInfo

    # 選擇模式
    if ($FullScreen) {
        # 設置 rdp 檔案
        $rdp = $rdp.Replace('${ip}'     ,$IP)
        $rdp = $rdp.Replace('${width}'  ,$ScreenInfo.Width)
        $rdp = $rdp.Replace('${height}' ,$ScreenInfo.Height)
        # 全螢幕參數
        $rdp = $rdp.Replace('screen mode id:i:1', 'screen mode id:i:2')
        $rdp = $rdp.Replace('connection type:i:7', 'connection type:i:3')
        $rdp = $rdp.Replace('authentication level:i:2', 'authentication level:i:0')        
    } else {
        # 最大化視窗(一開始初始化的數據就是這個所以留空)
        if($MaxWindows){
        # 自訂大小
        } elseif($Define) {
            if ($device_w -lt $rdpInfo.Resolution[0]) { $rdpInfo.Resolution[0] = $device_w }
            if ($device_h -lt $rdpInfo.Resolution[1]) { $rdpInfo.Resolution[1] = $device_h }
            if ($x1 -gt 0) { $rdpInfo.Winposstr[0] = $x1 } else { $rdpInfo.Winposstr[0] = ([Int64]$rdpInfo.Winposstr[2]-$rdpInfo.Resolution[0]-$rdpInfo.Margin[0]) }
            if ($y1 -gt 0) { $rdpInfo.Winposstr[1] = $y1 } else { $rdpInfo.Winposstr[1] = ([Int64]$rdpInfo.Winposstr[3]-$rdpInfo.Resolution[1]-$rdpInfo.Margin[1]) }
        # 預設模式分割成特定比例
        } else {
            $newWidth = RoundToEven($Ratio*$rdpInfo.Resolution[1])
            $diff = -$newWidth+$rdpInfo.Resolution[0]
            $nweX1 = $diff+$rdpInfo.Winposstr[0]
            # 如果沒有大於原本的寬就更換上去
            if ($newWidth -lt $rdpInfo.Resolution[0]) { $rdpInfo.Resolution[0] = $newWidth } $rdpInfo.Winposstr[0]  = $nweX1
        }
        
        # 轉換成rdp檔案
        $rdp = $rdpInfo|ConvertTo-Rdp $template_path1
    }
    # 複製密碼到剪貼簿
    if($PasswordCopy) { if ((Get-Clipboard) -ne $PasswordCopy) { Set-Clipboard $PasswordCopy } }
    # 儲存 rdp 檔案並開啟
    if ($OutputRDP) {
        $rdp|Set-Content $OutputRDP
    } else {
        $rdp|Set-Content "$env:TEMP\Default.rdp"
        Start-Process $rdp_path
    }
}
# rdpConnect 192.168.3.12
# rdpConnect 192.168.3.12 'pwcopy'
# rdpConnect 192.168.3.12 -Ratio:1.1
# rdpConnect 192.168.3.12 -FullScreen
# rdpConnect 192.168.3.12 -MaxWindows
# rdpConnect 192.168.3.12 -Define 1024 768



# 安裝到電腦的 PROFILE 參數內
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



# 下載離線包到電腦以便使用Bat雙擊離線開啟
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



# 儲存管理多個rdp清單
function rdpMgr {
    param (
        [Parameter(ParameterSetName = "")]
        [string] $Path,
        [Parameter(ParameterSetName = "")]
        [double] $Ratio = 16/11,
        [Parameter(ParameterSetName = "")]
        [switch] $FullScreen,
        [Parameter(ParameterSetName = "")]
        [switch] $EditList,
        [Parameter(ParameterSetName = "")]
        [System.Object] $Encoding
        
    )
    if (!$Path) {
        if ($__rdpMgrPath__) {
            $Path = $__rdpMgrPath__
        } elseif  ($PSScriptRoot){
            $Path = "$PSScriptRoot\rdpList.csv"
        } else {
            $Path = 'rdpList.csv'
        }
    }
    
    if ($EditList) {
        notepad.exe $Path
        return
    }
    
    if ($Encoding) { # Unicode,UTF7,UTF8,ASCII,UTF32,BigEndianUnicode,Default,OEM
        $list = Import-Csv $Path -Encoding:$Encoding
    } elseif ($__rdpMgrEncoding__) {
        $list = Import-Csv $Path -Encoding:$__rdpMgrEncoding__
    } else {
        $list = Import-Csv $Path
    }    
    
    $Serv = $list | Out-GridView -PassThru -Title:'rdpConnect'
    if ($Serv) {
        if ($FullScreen) {
            rdpConnect $Serv.IP -PasswordCopy:$Serv.PW -FullScreen:$FullScreen
        } else {
            rdpConnect $Serv.IP -PasswordCopy:$Serv.PW -Ratio:$Ratio
        }
    }
} # rdpMgr
