#Requires -Version 5.1

<#
.SYNOPSIS
    Calculates maximized RDP window size and position with DPI-aware pixel alignment.

.DESCRIPTION
    Computes the optimal RDP window dimensions and position for a maximized
    (but not full screen) remote desktop connection. The calculation accounts for:
    - Screen resolution and DPI scaling
    - Taskbar height (dynamic, retrieved from system)
    - Window title bar height (28 pixels at 100% scaling)
    - Window border margins (7 pixels at 100% scaling)
    - Pixel alignment to even numbers for crisp rendering

    This function implements a complex algorithm that has been fine-tuned to
    provide pixel-perfect alignment across different DPI settings (100%, 125%, 150%, etc.).

.PARAMETER IP
    The IP address or hostname of the remote computer.

.OUTPUTS
    PSCustomObject with extended RDP connection information:
    - Ip: Remote computer address
    - Resolution: Array of [optimal_width, optimal_height]
    - Winposstr: Array of [window_left, window_top, window_right, window_bottom]
    - Margin: Array of [total_width_margin, total_height_margin]
    - Scaling: DPI scaling factor
    - Path: Default RDP file path

.EXAMPLE
    $rdp = Get-MaximizedRdpSize -IP '192.168.1.100'
    $rdp | ConvertTo-RdpFileContent | Set-Content 'maximized.rdp'

.EXAMPLE
    $rdp = Get-MaximizedRdpSize '192.168.1.100'
    Write-Host "Resolution: $($rdp.Resolution[0])x$($rdp.Resolution[1])"
    Write-Host "Window position: [$($rdp.Winposstr[0]), $($rdp.Winposstr[1])] to [$($rdp.Winposstr[2]), $($rdp.Winposstr[3])]"

.NOTES
    Internal function - not exported from module.

    Magic numbers explained:
    - Title bar: 28px (30-2) at 100% DPI
    - Margin: 7px at 100% DPI
    - All values are scaled based on current DPI setting
    - Even-number rounding ensures pixel-perfect alignment

    The algorithm has been carefully tuned through multiple iterations.
    See rdpMaxSize.md for historical evolution of this calculation.
#>
function Get-MaximizedRdpSize {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory, Position = 0)]
        [String]$IP
    )

    # 獲取螢幕資訊
    $ScreenInfo = Get-ScreenInformation
    Write-Verbose "Screen info: $($ScreenInfo.Width)x$($ScreenInfo.Height) @ $($ScreenInfo.Scaling * 100)% scaling"

    [double]$Width = $ScreenInfo.Width
    [double]$Height = $ScreenInfo.Height
    [double]$Scaling = $ScreenInfo.Scaling

    # 初始數據
    $star = $ScreenInfo.TaskbarHeight
    $title = (30 - 2)
    $margin = 7

    Write-Verbose "Base dimensions: taskbar=$star, title=$title, margin=$margin"

    # 縮放後取到偶數
    $margin2 = [Math]::Round(($Scaling * $margin), 0, [MidpointRounding]::ToEven)
    $title2 = [Math]::Round(($Scaling * $title), 0, [MidpointRounding]::ToEven)
    $star2 = [Math]::Round(($Scaling * $star), 0, [MidpointRounding]::ToEven)

    Write-Verbose "Scaled dimensions: margin=$margin2, title=$title2, taskbar=$star2"

    # 計算實際邊緣寬度
    $mgW = $margin2 + $margin2 + 1
    $mgH = $title2 + 2 + $margin2 + 2
    $mgW = [Math]::Round(($mgW + 0.5), 0, [MidpointRounding]::ToEven)
    $mgH = [Math]::Round(($mgH + 0.5), 0, [MidpointRounding]::ToEven)

    Write-Verbose "Total margins: width=$mgW, height=$mgH"

    # 輸出視窗範圍
    $x2 = $Width
    $y2 = $Height - $star2
    $x1 = 0
    $y1 = [Math]::Round(($margin2 + 0.5), 0, [MidpointRounding]::ToEven)

    Write-Verbose "Window bounds: [$x1, $y1] to [$x2, $y2]"

    # 計算解度
    $w = $x2 - $x1 - $mgW
    $h = $y2 - $y1 - $mgH
    $w = [Math]::Round(($w - 0.5), 0, [MidpointRounding]::ToEven)
    $h = [Math]::Round(($h - 0.5), 0, [MidpointRounding]::ToEven)

    # 高DPI顯示器安全邊距（防止卷軸）
    if ($Scaling -ge 1.5) {
        $safetyMargin = [Math]::Ceiling($Scaling * 2)
        $h = $h - $safetyMargin
        Write-Verbose "Applied safety margin: -${safetyMargin}px for ${Scaling}x scaling"
    }

    Write-Verbose "Calculated resolution: ${w}x${h}"

    # 建立RDP
    $rdp = New-RdpConnectionInfo $IP $w $h $x1 $y1 $x2 $y2
    $rdp.Margin[0] = $mgW
    $rdp.Margin[1] = $mgH
    $rdp.Scaling = $Scaling

    Write-Verbose "RDP configuration complete for $IP"
    return $rdp
}
