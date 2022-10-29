# 獲取螢幕解析度
function GetScreenInfo {
    if (!$__GetScreenInfoOnce__) { $Script:__GetScreenInfoOnce__ = $true
        Add-Type -TypeDefinition:'using System; using System.Runtime.InteropServices; public class PInvoke { [DllImport("user32.dll")] public static extern IntPtr GetDC(IntPtr hwnd); [DllImport("gdi32.dll")] public static extern int GetDeviceCaps(IntPtr hdc, int nIndex); }'
    }
    $hdc = [PInvoke]::GetDC([IntPtr]::Zero)
    [pscustomobject]@{
        Width         = [PInvoke]::GetDeviceCaps($hdc, 118)
        Height        = [PInvoke]::GetDeviceCaps($hdc, 117)
        Refresh       = [PInvoke]::GetDeviceCaps($hdc, 116)
        Scaling       = [PInvoke]::GetDeviceCaps($hdc, 117) / [PInvoke]::GetDeviceCaps($hdc, 10)
        LogicalWeight = [PInvoke]::GetDeviceCaps($hdc, 8)
        LogicalHeight = [PInvoke]::GetDeviceCaps($hdc, 10)
    }
} if (!$ScreenInfo) { $ScreenInfo = (GetScreenInfo) } 
# $ScreenInfo

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
        
    )
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
} # New-RdpInfo '192.168.3.14'
# $rdpInfo = (New-RdpInfo '192.168.3.14' 3818 2034 0 10 3840 2100)
# $rdpInfo = (New-RdpInfo '192.168.3.14' -FullScreen)
# $rdpInfo
# return

# 轉換至RDP檔案
function ConvertTo-Rdp {
    param (
        [Parameter(ParameterSetName = "")]
        [string] $rdptplPath = "$PSScriptRoot\Template.rdp",
        [Parameter(ValueFromPipeline, ParameterSetName = "")]
        [System.Object] $InputObject
    )
    # 獲取樣板文件內容
    [String] $rdp = $null
    if ((Test-Path -PathType:Leaf $rdptplPath)) {
        $rdp = [IO.File]::ReadAllText($rdptplPath, [Text.Encoding]::Default)
    } if(!$rdp) {
        if ($PSScriptRoot) { Write-Warning "Download rdpTemplate from github because `"$rdptplPath`" doesn't exist." }
        if ($env:0) {
            $rdp = (([Io.File]::ReadAllText($env:0,[Text.Encoding]::Default) -split '[:]PwshScript')[3])
        } else {
            $rdp = Invoke-RestMethod('raw.githubusercontent.com/hunandy14/rdpConnect/master/Template.rdp')
        }
    } # $rdp
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
} # (New-RdpInfo -FullScreen)|ConvertTo-Rdp
# $rdpInfo = (New-RdpInfo '192.168.3.14' 3818 2034 0 10 3840 2100)
# $rdpInfo = (New-RdpInfo '192.168.3.14' -FullScreen)
# $rdp = ($rdpInfo|ConvertTo-Rdp)
# $rdp > 虛擬機14.rdp; explorer.exe 虛擬機14.rdp

# 計算最大化的視窗數值
function rdpMaxSize {
    param (
        [Parameter(Position = 0, ParameterSetName = "", Mandatory)]
        [String] $IP
    )
    # 獲取螢幕資訊
    [double] $Width   = $ScreenInfo.Width
    [double] $Height  = $ScreenInfo.Height
    [double] $Scaling = $ScreenInfo.Scaling
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
    # 建立RDP
    $rdp = New-RdpInfo $IP $w $h $x1 $y1 $x2 $y2
    $rdp.Margin[0] = $mgW
    $rdp.Margin[1] = $mgH
    $rdp.Scaling = $Scaling
    return $rdp
} # rdpMaxSize '192.168.2.14'
# $rdpInfo = rdpMaxSize '192.168.3.14'
# $rdpInfo = (New-RdpInfo '192.168.3.14' -FullScreen)
# $rdp = $rdpInfo|ConvertTo-Rdp
# $rdp|Out-File "虛擬機14.rdp"; Start-Process "虛擬機14.rdp"



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
} # rdpConnect 192.168.3.14
# rdpConnect 192.168.3.14 -Copy:'PassWD'
# rdpConnect 192.168.3.14 -Ratio:(16/10)
# rdpConnect 192.168.3.14 -FullScreen
# rdpConnect 192.168.3.14 -MaxWindows
# rdpConnect 192.168.3.14 -OutputRDP "run.rdp"
# rdpConnect 192.168.3.14 -Define 2560 1600 2000 300



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
    Invoke-WebRequest $URL -OutFile:"$Dir\rdpConnect.ps1"
    $URL  = "raw.githubusercontent.com/hunandy14/rdpConnect/master/Template.ps1"
    Invoke-WebRequest $URL -OutFile:"$Dir\Template.ps1"

    # 寫入[啟動文件]
    $impt = "Import-Module rdpConnect.ps1"
    if ($ForceAppend) {
        if (!((Get-Content $PROFILE)|Where-Object{$_ -eq $impt})) { Add-Content $PROFILE "`n$impt" }
        Write-Host "Has been Added rdpConnect to PROFILE." -ForegroundColor:Yellow
    } else {
        Set-Clipboard $impt
        Write-Host "Has been copy to Clipboard. Please paste it on the PROFILE." -ForegroundColor:Yellow
        notepad.exe $PROFILE
    }
} # Install



# 下載離線包到電腦以便使用Bat雙擊離線開啟
function WrapUp2Bat {
    param (
        $Path = [Environment]::GetFolderPath("Desktop")
    )
    # 移除文本中的註解
    function RemoveComment( [Object] $Content, [String] $Mark='#' ) {
        return [string](((($Content-split "`n") -replace("($Mark(?!')(.*?)$)|(\s+$)","") -notmatch('^\s*$'))) -join "`n")
    } # RemoveComment (Invoke-RestMethod bit.ly/Get-FileList)
    # 展開 irm 內容
    function ExpandIrm( [Object] $Content, [String] $Encoding='UTF8' ) {
        $bitlyLine=(($Content -split "`n") -match "bit.ly|raw.githubusercontent.com")
        foreach ($line in $bitlyLine) {
            $expand = $line -replace("(\s*\|\s*(Invoke-Expression|iex))|^iex","") |Invoke-Expression
            $Content = $Content.Replace($line, (RemoveComment $expand))
        }
        return ($Content)
    } # ExpandIrm (Invoke-RestMethod bit.ly/Get-FileList)
    
    # 下載
    $Url  = "raw.githubusercontent.com/hunandy14/rdpConnect/master/rdpMgr.bat"
    $Ct = Invoke-RestMethod $Url
    $Ct = ExpandIrm $Ct
    # $Ct = RemoveComment $Ct
    $Ct = $Ct.Replace("`n", "`r`n")
    # 輸出檔案
    $Encding = (PowerShell -NoP "([Text.Encoding]::Default).CodePage")
    $Enc = [Text.Encoding]::GetEncoding([int]$Encding)
    $Ct = $Ct.Replace("65001", $Encding)
    [IO.File]::WriteAllText("$Path\rdpMgr.bat", $Ct, $Enc);
    # 輸出CSV檔案
    $Url  = "raw.githubusercontent.com/hunandy14/rdpConnect/master/rdpList.csv"
    $Ct = Invoke-RestMethod $Url
    [IO.File]::WriteAllText("$Path\rdpList.csv", $Ct, $Enc);
} # WrapUp2Bat


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
            rdpConnect $Serv.IP -Copy:$Serv.PW -FullScreen:$FullScreen
        } else {
            rdpConnect $Serv.IP -Copy:$Serv.PW -Ratio:$Ratio
        }
    }
} # rdpMgr
# rdpMgr -FullScreen
