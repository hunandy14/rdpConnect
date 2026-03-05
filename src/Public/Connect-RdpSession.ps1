#Requires -Version 5.1

<#
.SYNOPSIS
    Connects to a remote desktop with automatic resolution and position optimization.

.DESCRIPTION
    Establishes an RDP connection with intelligent window sizing and positioning.
    Supports multiple connection modes:
    - Default: Custom aspect ratio (16:10 by default)
    - MaxWindows: Maximized window (fills screen except taskbar)
    - FullScreen: Full screen mode
    - Define: Custom resolution and position

    Features:
    - Automatic DPI scaling compensation
    - Taskbar height detection
    - Password clipboard management
    - Username injection

.PARAMETER IP
    The IP address or hostname of the remote computer. (Required)

.PARAMETER Ratio
    Aspect ratio for default mode (width/height).
    Default: 16/10 (1.6)
    Parameter set: A (Default)

.PARAMETER MaxWindows
    Use maximized window mode (fills screen except taskbar).
    Parameter set: B

.PARAMETER FullScreen
    Use full screen mode.
    Parameter set: C

.PARAMETER Define
    Enable custom resolution and position mode.
    Requires: device_w, device_h, and optionally x1, y1.
    Parameter set: D

.PARAMETER device_w
    Custom desktop width in pixels (Define mode).
    Must be less than or equal to maximum calculated width.
    Parameter set: D

.PARAMETER device_h
    Custom desktop height in pixels (Define mode).
    Must be less than or equal to maximum calculated height.
    Parameter set: D

.PARAMETER x1
    Window left position in pixels (Define mode).
    Default: -1 (auto-calculated)
    Parameter set: D

.PARAMETER y1
    Window top position in pixels (Define mode).
    Default: -1 (auto-calculated)
    Parameter set: D

.PARAMETER CopyPassWD
    Password to copy to clipboard before launching RDP.
    Useful for environments where RDP password saving is disabled.

.PARAMETER Username
    Username to inject into the RDP file.
    Adds "username:s:<value>" to RDP configuration.

.PARAMETER OutputRDP
    Output RDP file path. If specified, saves the RDP file instead of launching it.
    Parameter set: A (Default)

.OUTPUTS
    None. Launches RDP connection or saves RDP file.

.EXAMPLE
    Connect-RdpSession '192.168.1.100'
    Connects using default 16:10 ratio mode.

.EXAMPLE
    Connect-RdpSession '192.168.1.100' -Ratio (16/9)
    Connects with 16:9 aspect ratio.

.EXAMPLE
    Connect-RdpSession '192.168.1.100' -MaxWindows -CopyPassWD 'MyP@ssw0rd'
    Connects in maximized window mode and copies password to clipboard.

.EXAMPLE
    Connect-RdpSession '192.168.1.100' -FullScreen -Username 'admin'
    Connects in full screen mode with username pre-filled.

.EXAMPLE
    Connect-RdpSession '192.168.1.100' -Define -device_w 1920 -device_h 1080 -x1 100 -y1 50
    Connects with custom resolution (1920x1080) positioned at (100, 50).

.EXAMPLE
    Connect-RdpSession '192.168.1.100' -OutputRDP 'C:\Temp\server.rdp'
    Generates RDP file without launching the connection.

.NOTES
    Alias: rdpConnect (for backward compatibility)

    Password clipboard feature is designed for enterprise environments
    where GPO prevents RDP from saving credentials.
#>
function Connect-RdpSession {
    [CmdletBinding(DefaultParameterSetName = "A")]
    param (
        [Parameter(Mandatory, Position = 0, ParameterSetName = "")]
        [string]$IP,

        # Parameter Set A: Default ratio mode
        [Parameter(ParameterSetName = "A")]
        [double]$Ratio = (16 / 10),

        # Parameter Set B: Maximized window
        [Parameter(ParameterSetName = "B")]
        [switch]$MaxWindows,

        # Parameter Set C: Full screen
        [Parameter(ParameterSetName = "C")]
        [switch]$FullScreen,

        # Parameter Set D: Custom resolution and position
        [Parameter(ParameterSetName = "D")]
        [switch]$Define,

        [Parameter(Position = 1, ParameterSetName = "D")]
        [int64]$device_w = 0,

        [Parameter(Position = 2, ParameterSetName = "D")]
        [int64]$device_h = 0,

        [Parameter(Position = 3, ParameterSetName = "D")]
        [int64]$x1 = -1,

        [Parameter(Position = 4, ParameterSetName = "D")]
        [int64]$y1 = -1,

        # Common parameters (all parameter sets)
        [Parameter(ParameterSetName = "")]
        [String]$CopyPassWD,

        [Parameter(ParameterSetName = "")]
        [String]$Username,

        [Parameter(ParameterSetName = "")]
        [String]$OutputRDP
    )

    Write-Verbose "Connecting to RDP: $IP (Mode: $($PSCmdlet.ParameterSetName))"

    # Determine connection mode and create RDP configuration
    if ($FullScreen) {
        # Full screen mode
        Write-Verbose "Using full screen mode"
        $rdpInfo = New-RdpConnectionInfo $IP -FullScreen
    }
    else {
        # Start with maximized window calculation
        Write-Verbose "Calculating maximized window size"
        $rdpInfo = Get-MaximizedRdpSize $IP

        if ($MaxWindows) {
            # Maximized window mode (no additional adjustments needed)
            Write-Verbose "Using maximized window mode (default calculation)"
        }
        elseif ($Define) {
            # Custom resolution and position mode
            Write-Verbose "Applying custom resolution: ${device_w}x${device_h}"

            # Update resolution (only if within valid range)
            if ($device_w -lt $rdpInfo.Resolution[0]) {
                $rdpInfo.Resolution[0] = $device_w
            }
            if ($device_h -lt $rdpInfo.Resolution[1]) {
                $rdpInfo.Resolution[1] = $device_h
            }

            # Recalculate position limits based on new resolution
            $rdpInfo.Winposstr[0] = ([Int64]$rdpInfo.Winposstr[2] - $rdpInfo.Resolution[0] - $rdpInfo.Margin[0])
            $rdpInfo.Winposstr[1] = ([Int64]$rdpInfo.Winposstr[3] - $rdpInfo.Resolution[1] - $rdpInfo.Margin[1])

            # Apply custom position (if within valid range)
            if (($x1 -gt -1) -and ($x1 -le $rdpInfo.Winposstr[0])) {
                $rdpInfo.Winposstr[0] = $x1
            }
            if (($y1 -gt -1) -and ($y1 -le $rdpInfo.Winposstr[0])) {
                $rdpInfo.Winposstr[1] = $y1
            }

            Write-Verbose "Final resolution: $($rdpInfo.Resolution[0])x$($rdpInfo.Resolution[1])"
            Write-Verbose "Window position: [$($rdpInfo.Winposstr[0]), $($rdpInfo.Winposstr[1])]"
        }
        else {
            # Default ratio mode
            Write-Verbose "Applying aspect ratio: $Ratio"

            $newWidth = ($Ratio * $rdpInfo.Resolution[1])
            $diff = (-$newWidth + $rdpInfo.Resolution[0])
            $newX1 = ($diff + $rdpInfo.Winposstr[0])

            # Apply new width if it's smaller than maximum
            if ($newWidth -lt $rdpInfo.Resolution[0]) {
                $rdpInfo.Resolution[0] = [int]$newWidth
            }
            $rdpInfo.Winposstr[0] = [int]$newX1

            Write-Verbose "Adjusted resolution: $($rdpInfo.Resolution[0])x$($rdpInfo.Resolution[1])"
        }
    }

    # Convert to RDP file content
    Write-Verbose "Generating RDP file content"
    $rdp = $rdpInfo | ConvertTo-RdpFileContent

    # Inject username if provided
    if ($Username) {
        Write-Verbose "Adding username: $Username"
        $rdp += "`nusername:s:$Username"
    }

    # Copy password to clipboard if provided
    if ($CopyPassWD) {
        $currentClipboard = Get-Clipboard -ErrorAction SilentlyContinue
        if ($currentClipboard -ne $CopyPassWD) {
            Write-Verbose "Copying password to clipboard"
            Set-Clipboard $CopyPassWD
        }
    }

    # Save or launch RDP file
    if ($OutputRDP) {
        Write-Verbose "Saving RDP file to: $OutputRDP"
        $rdp | Set-Content $OutputRDP -Encoding UTF8
        Write-Host "RDP file saved: $OutputRDP" -ForegroundColor Green
    }
    else {
        $rdp_path = "$env:TEMP\Default.rdp"
        Write-Verbose "Saving temporary RDP file: $rdp_path"
        $rdp | Set-Content $rdp_path -Encoding UTF8

        Write-Verbose "Launching RDP connection to $IP"
        Start-Process $rdp_path
    }
}
