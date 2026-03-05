#Requires -Version 5.1

<#
.SYNOPSIS
    Creates an RDP connection information object.

.DESCRIPTION
    Constructs a PSCustomObject containing RDP connection parameters including:
    - Remote IP address
    - Desktop resolution
    - Window position coordinates
    - Full screen mode flag

    Supports two parameter sets:
    - Default: Custom resolution and window position
    - FullScreen: Full screen mode using current screen resolution

.PARAMETER ip
    The IP address or hostname of the remote computer.
    Default: '127.0.0.1'

.PARAMETER device_w
    Desktop width in pixels (Default parameter set).
    Default: 0

.PARAMETER device_h
    Desktop height in pixels (Default parameter set).
    Default: 0

.PARAMETER x1
    Window left coordinate (Default parameter set).
    Default: 0

.PARAMETER y1
    Window top coordinate (Default parameter set).
    Default: 0

.PARAMETER x2
    Window right coordinate (Default parameter set).
    Default: 0

.PARAMETER y2
    Window bottom coordinate (Default parameter set).
    Default: 0

.PARAMETER FullScreen
    Enables full screen mode using current screen resolution.

.OUTPUTS
    PSCustomObject with properties:
    - Ip: Remote computer address
    - Resolution: Array of [width, height]
    - FullScreen: Boolean (if full screen mode)
    - Winposstr: Array of [x1, y1, x2, y2] (if windowed mode)
    - Margin: Array of [width_margin, height_margin]
    - Scaling: DPI scaling factor (populated later)
    - Path: Default RDP file path

.EXAMPLE
    $rdp = New-RdpConnectionInfo -ip '192.168.1.100'
    Creates a default RDP info object for the specified IP.

.EXAMPLE
    $rdp = New-RdpConnectionInfo -ip '192.168.1.100' -FullScreen
    Creates an RDP info object configured for full screen mode.

.EXAMPLE
    $rdp = New-RdpConnectionInfo -ip '192.168.1.100' -device_w 1920 -device_h 1080 -x1 0 -y1 0 -x2 1920 -y2 1080
    Creates an RDP info object with specific resolution and window position.

.NOTES
    Internal function - not exported from module.
    Called by Get-MaximizedRdpSize and Connect-RdpSession.
#>
function New-RdpConnectionInfo {
    [CmdletBinding(DefaultParameterSetName = "Default")]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Position = 0, ParameterSetName = "")]
        [string]$ip = '127.0.0.1',

        [Parameter(Position = 1, ParameterSetName = "Default")]
        [string]$device_w = 0,

        [Parameter(Position = 2, ParameterSetName = "Default")]
        [string]$device_h = 0,

        [Parameter(Position = 3, ParameterSetName = "Default")]
        [string]$x1 = 0,

        [Parameter(Position = 4, ParameterSetName = "Default")]
        [string]$y1 = 0,

        [Parameter(Position = 5, ParameterSetName = "Default")]
        [string]$x2 = 0,

        [Parameter(Position = 6, ParameterSetName = "Default")]
        [string]$y2 = 0,

        [Parameter(ParameterSetName = "FullScreen")]
        [switch]$FullScreen
    )

    # Get current screen information
    $ScreenInfo = Get-ScreenInformation
    Write-Verbose "Screen resolution: $($ScreenInfo.Width)x$($ScreenInfo.Height)"

    # Return full screen configuration
    if ($FullScreen) {
        Write-Verbose "Creating full screen RDP configuration"
        return [PSCustomObject]@{
            Ip         = $ip
            Resolution = @($ScreenInfo.Width, $ScreenInfo.Height)
            FullScreen = $true
            Path       = '.\Default.rdp'
        }
    }

    # Return windowed configuration
    Write-Verbose "Creating windowed RDP configuration: ${device_w}x${device_h}"
    return [PSCustomObject]@{
        Ip         = $ip
        Resolution = @($device_w, $device_h)
        Winposstr  = @($x1, $y1, $x2, $y2)
        Margin     = @(0, 0)
        Scaling    = $null
        Path       = '.\Default.rdp'
    }
}
