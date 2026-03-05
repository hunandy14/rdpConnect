#Requires -Version 5.1

<#
.SYNOPSIS
    Gets screen information including resolution, DPI scaling, and taskbar height.

.DESCRIPTION
    Uses Windows API (P/Invoke) to retrieve detailed screen information:
    - Screen resolution (Width, Height)
    - Refresh rate
    - DPI scaling factor
    - Taskbar height (both physical and logical pixels)

    This function uses a static type initialization pattern to define P/Invoke
    signatures only once per PowerShell session.

.OUTPUTS
    PSCustomObject with the following properties:
    - Width: Screen width in pixels
    - Height: Screen height in pixels
    - Refresh: Refresh rate in Hz
    - TaskbarHeight: Taskbar height in physical pixels
    - Scaling: DPI scaling factor (e.g., 1.0, 1.25, 1.5)
    - LogicalWidth: Logical width (before scaling)
    - LogicalHeight: Logical height (before scaling)
    - LogicalTaskbarHeight: Taskbar height scaled

.EXAMPLE
    $screen = Get-ScreenInformation
    Write-Host "Screen: $($screen.Width)x$($screen.Height) at $($screen.Scaling * 100)% scaling"

.NOTES
    Internal function - not exported from module.
    Uses a script-scope variable ($Script:__GetScreenInfoOnce__) to ensure
    Add-Type is called only once per session.
#>
function Get-ScreenInformation {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    # Initialize P/Invoke types only once per session
    # Check if type already exists in current session
    if (-not ([System.Management.Automation.PSTypeName]'PInvoke').Type) {
        Add-Type -TypeDefinition @'
            using System;
            using System.Runtime.InteropServices;
            public class PInvoke {
                [DllImport("user32.dll")] public static extern IntPtr GetDC(IntPtr hwnd);
                [DllImport("gdi32.dll")] public static extern int GetDeviceCaps(IntPtr hdc, int nIndex);
                [DllImport("user32.dll", SetLastError = true)] public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
                [DllImport("user32.dll", SetLastError = true)] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
                [StructLayout(LayoutKind.Sequential)]
                public struct RECT {
                    public int Left;
                    public int Top;
                    public int Right;
                    public int Bottom;
                }
            }
'@
    }

    Write-Verbose "Querying screen information via Windows API"

    # Get device context
    $hdc = [PInvoke]::GetDC([IntPtr]::Zero)

    # Calculate DPI scaling factor
    # VERTRES (117) = vertical resolution in pixels
    # DESKTOPVERTRES (10) = vertical resolution of desktop
    $Scaling = [PInvoke]::GetDeviceCaps($hdc, 117) / [PInvoke]::GetDeviceCaps($hdc, 10)

    # Get taskbar dimensions
    $taskbarHandle = [PInvoke]::FindWindow("Shell_TrayWnd", $null)
    $taskbarRect = New-Object 'PInvoke+RECT'
    if (![PInvoke]::GetWindowRect($taskbarHandle, [ref]$taskbarRect)) {
        throw "Failed to get taskbar dimensions."
    }
    $taskbarHeight = $taskbarRect.Bottom - $taskbarRect.Top

    # Return screen information object
    [pscustomobject]@{
        Width                = [PInvoke]::GetDeviceCaps($hdc, 118)  # HORZRES
        Height               = [PInvoke]::GetDeviceCaps($hdc, 117)  # VERTRES
        Refresh              = [PInvoke]::GetDeviceCaps($hdc, 116)  # VREFRESH
        TaskbarHeight        = $taskbarHeight
        Scaling              = $Scaling
        LogicalWidth         = [PInvoke]::GetDeviceCaps($hdc, 8)   # HORZRES
        LogicalHeight        = [PInvoke]::GetDeviceCaps($hdc, 10)  # VERTRES
        LogicalTaskbarHeight = [Math]::Round($taskbarHeight * $Scaling)
    }
}
