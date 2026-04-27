# 嵌入式 RDP 樣板（取代外部 Template.rdp）
$script:RdpTemplate = @'
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
'@

# 獲取螢幕解析度
function GetScreenInfo {
    [CmdletBinding()]
    param()

    # 載入 ScreenHelper 型別
    if (-not ('ScreenHelper' -as [type])) {
        Write-Verbose "ScreenHelper 型別不存在，正在載入..."
        Add-Type -TypeDefinition @'
            using System;
            using System.Runtime.InteropServices;
            public class ScreenHelper {
                [StructLayout(LayoutKind.Sequential)]
                public struct RECT {
                    public int Left, Top, Right, Bottom;
                }
                [DllImport("shcore.dll")]
                public static extern int SetProcessDpiAwareness(int awareness);
                [DllImport("user32.dll")]
                public static extern bool SystemParametersInfo(int uiAction, int uiParam, out RECT pvParam, int fWinIni);
                [DllImport("user32.dll")]
                public static extern IntPtr MonitorFromPoint(long pt, uint dwFlags);
                [DllImport("shcore.dll")]
                public static extern int GetDpiForMonitor(IntPtr hMonitor, int dpiType, out uint dpiX, out uint dpiY);
                [DllImport("gdi32.dll")]
                public static extern int GetDeviceCaps(IntPtr hdc, int nIndex);
                [DllImport("user32.dll")]
                public static extern IntPtr GetDC(IntPtr hwnd);
            }
'@
        Write-Verbose "ScreenHelper 型別載入完成"
    } else { Write-Verbose "ScreenHelper 型別已存在，跳過載入" }

    # 主螢幕 DPI (per-monitor)
    [void][ScreenHelper]::SetProcessDpiAwareness(2) # 啟用 Per-Monitor DPI 感知，取得真實物理像素
    $hMonitor = [ScreenHelper]::MonitorFromPoint(0, 1) # 1 = MONITOR_DEFAULTTOPRIMARY
    $dpiX, $dpiY = [uint32]0, [uint32]0
    [void][ScreenHelper]::GetDpiForMonitor($hMonitor, 0, [ref]$dpiX, [ref]$dpiY) # 0 = MDT_EFFECTIVE_DPI
    $Scaling = $dpiX / 96

    # 物理解析度與更新率
    $hdc = [ScreenHelper]::GetDC([IntPtr]::Zero)
    $Width   = [ScreenHelper]::GetDeviceCaps($hdc, 118)  # DESKTOPHORZRES
    $Height  = [ScreenHelper]::GetDeviceCaps($hdc, 117)  # DESKTOPVERTRES
    $Refresh = [ScreenHelper]::GetDeviceCaps($hdc, 116)  # VREFRESH

    # Taskbar 高度 = 螢幕高度 - 工作區高度
    $workArea = New-Object 'ScreenHelper+RECT'
    [void][ScreenHelper]::SystemParametersInfo(0x0030, 0, [ref]$workArea, 0) # SPI_GETWORKAREA
    $TaskbarHeight = $Height - ($workArea.Bottom - $workArea.Top)

    # 輸出螢幕解資訊
    Write-Verbose "Resolution=${Width}x${Height} DPI=${dpiX} Scaling=${Scaling} Taskbar=${TaskbarHeight}px Refresh=${Refresh}Hz"
    [pscustomobject]@{
        Width         = $Width
        Height        = $Height
        Refresh       = $Refresh
        Scaling       = $Scaling
        TaskbarHeight = $TaskbarHeight
    }
}

# RDP結構
function New-RdpInfo {
    [CmdletBinding(DefaultParameterSetName = "Default")]
    param (
        [Parameter(Position = 0, ParameterSetName = "")]
        [string] $ip ='127.0.0.1',
        [Parameter(Position = 1, ParameterSetName = "Default")]
        [string] $device_w=0,
        [Parameter(Position = 2, ParameterSetName = "Default")]
        [string] $device_h=0,
        [Parameter(Position = 3, ParameterSetName = "Default")]
        [string] $x1=0,
        [Parameter(Position = 4, ParameterSetName = "Default")]
        [string] $y1=0,
        [Parameter(Position = 5, ParameterSetName = "Default")]
        [string] $x2=0,
        [Parameter(Position = 6, ParameterSetName = "Default")]
        [string] $y2=0,
        [Parameter(ParameterSetName = "FullScreen")]
        [switch] $FullScreen
    ) $ScreenInfo = GetScreenInfo
    if ($FullScreen) {
        return [PSCustomObject]@{
            Ip         = $ip
            Resolution = @($ScreenInfo.Width, $ScreenInfo.Height)
            FullScreen = $true
            Path       = '.\Default.rdp'
        }
    }
    return [PSCustomObject]@{
        Ip         = $ip
        Resolution = @($device_w,$device_h)
        Winposstr  = @($x1, $y1, $x2, $y2)
        Margin     = @(0, 0)
        Scaling    = $null
        Path       = '.\Default.rdp'
    }
}

# 轉換至RDP檔案（預設使用嵌入式樣板，可指定外部檔案覆蓋）
function ConvertTo-Rdp {
    param (
        [Parameter(ParameterSetName = "")]
        [string] $rdptplPath,
        [Parameter(ValueFromPipeline, ParameterSetName = "")]
        [System.Object] $InputObject
    )
    # 樣板來源：有指定外部路徑且檔案存在則讀檔，否則用嵌入式樣板
    [String] $rdp = if ($rdptplPath -and (Test-Path -PathType:Leaf $rdptplPath)) {
        [IO.File]::ReadAllText($rdptplPath, [Text.Encoding]::Default)
    } else { $script:RdpTemplate }

    # 設置 rdp 檔案
    $rdp = $rdp.Replace('${ip}'     ,$InputObject.Ip)
    $rdp = $rdp.Replace('${width}'  ,$InputObject.Resolution[0])
    $rdp = $rdp.Replace('${height}' ,$InputObject.Resolution[1])
    # 視窗化參數
    if ($InputObject.Winposstr) {
        $rdp = $rdp.Replace('${x1}'     ,$InputObject.Winposstr[0])
        $rdp = $rdp.Replace('${y1}'     ,$InputObject.Winposstr[1])
        $rdp = $rdp.Replace('${x2}'     ,$InputObject.Winposstr[2])
        $rdp = $rdp.Replace('${y2}'     ,$InputObject.Winposstr[3])
    }
    # 全螢幕參數
    if ($InputObject.FullScreen) {
        $rdp = $rdp.Replace('screen mode id:i:1', 'screen mode id:i:2')
        $rdp = $rdp.Replace('connection type:i:7', 'connection type:i:3')
        $rdp = $rdp.Replace('authentication level:i:2', 'authentication level:i:0')
        $rdp = $rdp.Replace('${x1}',0)
        $rdp = $rdp.Replace('${y1}',0)
        $rdp = $rdp.Replace('${x2}',0)
        $rdp = $rdp.Replace('${y2}',0)
    }
    return $rdp
}

# 計算最大化的視窗數值
function rdpMaxSize {
    param (
        [Parameter(Position = 0, ParameterSetName = "", Mandatory)]
        [String] $IP
    ) $ScreenInfo = GetScreenInfo
    # 獲取螢幕資訊
    [double] $Width   = $ScreenInfo.Width
    [double] $Height  = $ScreenInfo.Height
    [double] $Scaling = $ScreenInfo.Scaling

    # 初始數據
    $title  = (30-2)
    $margin = 7
    $title2  = [Math]::Round(($Scaling*$title ), 0, [MidpointRounding]::ToEven)
    $margin2 = [Math]::Round(($Scaling*$margin), 0, [MidpointRounding]::ToEven)

    # 計算實際邊緣寬度
    $mgW = $margin2+$margin2+1
    $mgH = $title2+2+$margin2+2
    $mgW = [Math]::Round(($mgW+0.5), 0, [MidpointRounding]::ToEven)
    $mgH = [Math]::Round(($mgH+0.5), 0, [MidpointRounding]::ToEven)

    # 輸出視窗範圍
    $x1 = 0
    $y1 = [Math]::Round(($margin2+0.5), 0, [MidpointRounding]::ToEven)
    $x2 = $Width
    $y2 = $Height - $ScreenInfo.TaskbarHeight

    # 計算解度
    $w = $x2-$x1-$mgW
    $h = $y2-$y1-$mgH
    $w = [Math]::Round(($w-0.5), 0, [MidpointRounding]::ToEven)
    $h = [Math]::Round(($h-0.5), 0, [MidpointRounding]::ToEven)

    # 建立RDP
    $rdp = New-RdpInfo $IP $w $h $x1 $y1 $x2 $y2
    $rdp.Margin[0] = $mgW
    $rdp.Margin[1] = $mgH
    $rdp.Scaling = $Scaling
    return $rdp
}

# 連接到rdp遠端
function rdpConnect {
    [CmdletBinding(DefaultParameterSetName = "A")]
    param (
        [Parameter(Mandatory, Position = 0, ParameterSetName = "")]
        [string] $IP,
        # 傻瓜包
        [Parameter(ParameterSetName = "A")] # 預設模式 (特定比例)
        [double] $Ratio = (16/10),
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
        [int64] $x1 = -1,
        [Parameter(Position = 4, ParameterSetName = "D")]
        [int64] $y1 = -1,
        # 複製密碼
        [Parameter(ParameterSetName = "")]
        [String] $CopyPassWD,
        # 使用者名稱
        [Parameter(ParameterSetName = "")]
        [String] $Username,
        # 輸出rdp檔案
        [Parameter(ParameterSetName = "A")]
        [String] $OutputRDP
    )
    # 選擇模式
    if ($FullScreen) {
        $rdpInfo = New-RdpInfo $IP -FullScreen
    } else {
        $rdpInfo = rdpMaxSize $IP
        # 最大化視窗(一開始初始化的數據就是這個所以留空)
        if($MaxWindows){
        # 自訂大小
        } elseif($Define) {
            # 符合範圍內才更新解析度
            if ($device_w -lt $rdpInfo.Resolution[0]) { $rdpInfo.Resolution[0] = $device_w }
            if ($device_h -lt $rdpInfo.Resolution[1]) { $rdpInfo.Resolution[1] = $device_h }
            # 根據更新的解析度計算(x1, y1)的上限值
            $rdpInfo.Winposstr[0] = ([Int64]$rdpInfo.Winposstr[2]-$rdpInfo.Resolution[0]-$rdpInfo.Margin[0])
            $rdpInfo.Winposstr[1] = ([Int64]$rdpInfo.Winposstr[3]-$rdpInfo.Resolution[1]-$rdpInfo.Margin[1])
            # 符合範圍內才更新(x1, y1)
            if (($x1 -gt -1) -and ($x1 -le $rdpInfo.Winposstr[0])) { $rdpInfo.Winposstr[0] = $x1 }
            if (($y1 -gt -1) -and ($y1 -le $rdpInfo.Winposstr[0])) { $rdpInfo.Winposstr[1] = $y1 }
        # 預設模式分割成特定比例
        } else {
            $newWidth = ($Ratio*$rdpInfo.Resolution[1])
            $diff     = (-$newWidth+$rdpInfo.Resolution[0])
            $nweX1    = ($diff+$rdpInfo.Winposstr[0])
            # 如果沒有大於原本的寬就更換上去
            if ($newWidth -lt $rdpInfo.Resolution[0]) {
                $rdpInfo.Resolution[0] = [int]$newWidth
            } $rdpInfo.Winposstr[0]  = [int]$nweX1
        }
    }
    # 轉換成rdp檔案
    $rdp = $rdpInfo|ConvertTo-Rdp
    if ($Username) { $rdp += "`nusername:s:$Username" }

    # 複製密碼到剪貼簿
    if($CopyPassWD) { if ((Get-Clipboard) -ne $CopyPassWD) { Set-Clipboard $CopyPassWD } }
    # 儲存 rdp 檔案並開啟
    if ($OutputRDP) {
        $rdp|Set-Content $OutputRDP
    } else {
        $rdp_path = "$env:TEMP\Default.rdp"
        $rdp|Set-Content $rdp_path; Start-Process $rdp_path
    }
    # return $rdpInfo
}

# 儲存管理多個rdp清單
function rdpMgr {
    param (
        [Parameter(ParameterSetName = "")]
        [string] $Path,
        [Parameter(ParameterSetName = "")]
        [double] $Ratio = (16/10),
        [Parameter(ParameterSetName = "")]
        [switch] $FullScreen,
        [Parameter(ParameterSetName = "")]
        [switch] $Edit,
        [Parameter(ParameterSetName = "")]
        [int] $Encoding = (([Text.Encoding]::Default).CodePage)

    )
    # 編輯CSV檔案
    if ($Edit) { notepad.exe $Path; return }
    # 預設路徑
    if (!$Path) {
        if ($__rdpMgrPath__) { # 全域變數設定的位置
            $Path = $__rdpMgrPath__
        } else { # 工作目錄的位置
            if  ($PSScriptRoot){
                $Path = "$PSScriptRoot\rdpList.csv"
            } else { $Path = '.\rdpList.csv' }
        }
    }

    # 編碼
    if ($__rdpMgrEncoding__) { $Encoding = $__rdpMgrEncoding__ }
    $Enc = [Text.Encoding]::GetEncoding($Encoding)
    # 讀取CSV檔案
    $list = [IO.File]::ReadAllText($Path, $Enc)|ConvertFrom-Csv

    # 執行rdp連線
    $Serv = $list | Out-GridView -PassThru -Title:'rdpConnect'
    if ($Serv) {
        if ($FullScreen) {
            rdpConnect $Serv.IP -Copy:$Serv.PW -Username:$Serv.AC -FullScreen:$FullScreen
        } else {
            rdpConnect $Serv.IP -Copy:$Serv.PW -Username:$Serv.AC -Ratio:$Ratio
        }
    }
}
