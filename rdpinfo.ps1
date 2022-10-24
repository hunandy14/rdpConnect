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
        LogicalHeight = [PInvoke]::GetDeviceCaps($hdc, 10)
        LogicalWeight = [PInvoke]::GetDeviceCaps($hdc, 8)
    }
} $ScreenInfo = (GetScreenInfo) # ;$ScreenInfo


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
        [double] $Scaling
    )
    # 初始數據
    $star   = 40
    $title  = (30-2)
    $margin = 7
    # 縮放後取到偶數
    $margin2 = ($Scaling*$margin)
    $title2  = ($Scaling*$title )
    $star2   = ($Scaling*$star  )
    # $margin2 = [Math]::Round(($Scaling*$margin), 0, [MidpointRounding]::ToEven)
    # $title2  = [Math]::Round(($Scaling*$title ), 0, [MidpointRounding]::ToEven)
    # $star2   = [Math]::Round(($Scaling*$star  ), 0, [MidpointRounding]::ToEven)
    # Write-Host $margin2
    # 計算實際邊緣寬度
    $mgW = ($margin2+$margin2+1)
    $mgH = ($title2+2+$margin2+2)
    $mgW = ($mgW)
    $mgH = ($mgH)
    # $mgW = RoundToEven($mgW+0.5)
    # $mgH = RoundToEven($mgH+0.5)
    # $mgW = [Math]::Round(($mgW+0.5), 0, [MidpointRounding]::ToEven)
    # $mgH = [Math]::Round(($mgH+0.5), 0, [MidpointRounding]::ToEven)
    # 輸出視窗範圍
    $x2 = $Width
    $y2 = ($Height - $star2)
    $x1 = 0
    $y1 = ($margin2)
    # $y1 = RoundToEven($margin2+0.5)
    # $y1 = [Math]::Round(($margin2+0.5), 0, [MidpointRounding]::ToEven)
    
    # 計算解度
    $w = FloorToEven($x2-$x1-$mgW)
    $h = FloorToEven($y2-$y1-$mgH)
    # $w = [Math]::Round(($w-0.5), 0, [MidpointRounding]::ToEven)
    # $h = [Math]::Round(($h-0.5), 0, [MidpointRounding]::ToEven)
    # 輸出rdpInfo
    $rdp = [PSCustomObject]@{
        Ip         = $ip
        Resolution = @($w,$h)
        Winposstr  = @($x1, $y1, $x2, $y2)
        Margin     = @($mgW, $mgH)
        Scaling    = $Scaling
        Path       = '.\Default.rdp'
    }
    return $rdp
} # rdpMaxSize $ScreenInfo.Width $ScreenInfo.Height $ScreenInfo.Scaling
rdpMaxSize 2560 1600 1.0  | Select-Object Scaling,Resolution,Winposstr
rdpMaxSize 2560 1600 1.25 | Select-Object Scaling,Resolution,Winposstr
rdpMaxSize 2560 1600 1.5  | Select-Object Scaling,Resolution,Winposstr



# 新增 RdpInfo
function New-RdpInfo {
    [CmdletBinding(DefaultParameterSetName = "Default")]
    param (
        [Parameter(Position = 0, ParameterSetName = "")]
        [string] $ip ='127.0.0.1',
        # 預設::初始化成0
        [Parameter(ParameterSetName = "Default")]
        [string] $device_w=0,
        [Parameter(ParameterSetName = "Default")]
        [string] $device_h=0,
        [Parameter(ParameterSetName = "Default")]
        [string] $x1=0,
        [Parameter(ParameterSetName = "Default")]
        [string] $y1=0,
        [Parameter(ParameterSetName = "Default")]
        [string] $x2=0,
        [Parameter(ParameterSetName = "Default")]
        [string] $y2=0,
        # 可選::初始化成最大解析度
        [Parameter(Position = 0, ParameterSetName = "InitMaxScrSize")]
        [switch] $InitMaxScrSize
        
    ) 
    $rdp = [PSCustomObject]@{
        Ip         = $ip
        Resolution = @($device_w,$device_h)
        Winposstr  = @($x1, $y1, $x2, $y2)
        Margin     = @(0, 0)
        Scaling    = 1.0
        Path       = '.\Default.rdp'
    }
    if ($InitMaxScrSize) {
        $rdp.Resolution = @($ScreenInfo.Width,$ScreenInfo.Height)
        $rdp.Winposstr  = @($x1, $y1, $x2, $y2)
        $rdp.Margin     = @(0, 0)
        $rdp.Scaling    = 1.0
    }
    return $rdp
} #New-RdpInfo -InitMaxScrSize





























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
        [double] $Scaling
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
    $rdp.Scaling = $Scaling
    return $rdp
}

