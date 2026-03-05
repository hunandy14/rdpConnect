#Requires -Version 5.1

<#
.SYNOPSIS
    Converts an RDP connection info object to RDP file content.

.DESCRIPTION
    Takes an RDP connection information object and generates the complete
    RDP file content string by:
    1. Loading the RDP template from various sources (priority order)
    2. Replacing placeholder variables with actual values
    3. Adjusting settings for full screen mode if needed

    Template loading priority:
    1. Specified file path (rdptplPath parameter)
    2. Embedded template ($Script:EmbeddedRdpTemplate, used in standalone mode)
    3. BAT file embedded template ($env:0, used in rdpMgr.bat)
    4. Remote GitHub download (fallback)

.PARAMETER rdptplPath
    Path to the RDP template file.
    Default: $PSScriptRoot\Resources\Template.rdp (in module context)

.PARAMETER InputObject
    RDP connection information object from New-RdpConnectionInfo.
    Must contain:
    - Ip: Remote computer address
    - Resolution: Array of [width, height]
    - FullScreen: Boolean (optional)
    - Winposstr: Array of [x1, y1, x2, y2] (optional, for windowed mode)

.OUTPUTS
    String containing the complete RDP file content ready to be written to a file.

.EXAMPLE
    $rdpInfo = New-RdpConnectionInfo -ip '192.168.1.100' -device_w 1920 -device_h 1080
    $content = $rdpInfo | ConvertTo-RdpFileContent
    $content | Set-Content 'connection.rdp'

.EXAMPLE
    $rdpInfo = New-RdpConnectionInfo -ip '192.168.1.100' -FullScreen
    $content = ConvertTo-RdpFileContent -InputObject $rdpInfo
    $content | Set-Content 'fullscreen.rdp'

.NOTES
    Internal function - not exported from module.
    Template variables that will be replaced:
    - ${ip}: Remote IP address
    - ${width}: Desktop width
    - ${height}: Desktop height
    - ${x1}, ${y1}, ${x2}, ${y2}: Window position coordinates
#>
function ConvertTo-RdpFileContent {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter()]
        [string]$rdptplPath,

        [Parameter(ValueFromPipeline)]
        [System.Object]$InputObject
    )

    # Determine template path (module or script context)
    if (-not $rdptplPath) {
        if ($PSScriptRoot) {
            # Module context: Resources folder relative to this script
            $rdptplPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'Resources\Template.rdp'
        } else {
            # Fallback for dot-sourced context
            $rdptplPath = '.\Template.rdp'
        }
    }

    Write-Verbose "Template path: $rdptplPath"

    # Load RDP template (priority order)
    [String]$rdp = $null

    # Priority 1: Specified file path
    if ((Test-Path -PathType Leaf $rdptplPath)) {
        Write-Verbose "Loading template from file: $rdptplPath"
        $rdp = [IO.File]::ReadAllText($rdptplPath, [Text.Encoding]::Default)
    }

    # Priority 2: Embedded template (Standalone mode)
    if (-not $rdp -and $Script:EmbeddedRdpTemplate) {
        Write-Verbose "Using embedded RDP template (Standalone mode)"
        $rdp = $Script:EmbeddedRdpTemplate
    }

    # Priority 3: BAT file embedded template (rdpMgr.bat mode)
    if (-not $rdp -and $env:0) {
        Write-Verbose "Extracting template from BAT file: $env:0"
        $batContent = [IO.File]::ReadAllText($env:0, [Text.Encoding]::Default)
        $rdp = ($batContent -split '[:]PwshScript')[3]
    }

    # Priority 4: Remote GitHub download (fallback)
    if (-not $rdp) {
        $url = 'raw.githubusercontent.com/hunandy14/rdpConnect/master/Template.rdp'
        Write-Warning "Downloading template from GitHub: $url"
        try {
            $rdp = Invoke-RestMethod $url
        }
        catch {
            throw "Failed to load RDP template from all sources: $_"
        }
    }

    if (-not $rdp) {
        throw "RDP template is empty or could not be loaded."
    }

    Write-Verbose "Template loaded successfully (length: $($rdp.Length) chars)"

    # Replace placeholder variables
    Write-Verbose "Replacing placeholders: IP=$($InputObject.Ip), Resolution=$($InputObject.Resolution[0])x$($InputObject.Resolution[1])"
    $rdp = $rdp.Replace('${ip}', $InputObject.Ip)
    $rdp = $rdp.Replace('${width}', $InputObject.Resolution[0])
    $rdp = $rdp.Replace('${height}', $InputObject.Resolution[1])

    # Replace window position parameters (windowed mode)
    if ($InputObject.Winposstr) {
        Write-Verbose "Applying windowed mode settings"
        $rdp = $rdp.Replace('${x1}', $InputObject.Winposstr[0])
        $rdp = $rdp.Replace('${y1}', $InputObject.Winposstr[1])
        $rdp = $rdp.Replace('${x2}', $InputObject.Winposstr[2])
        $rdp = $rdp.Replace('${y2}', $InputObject.Winposstr[3])
    }

    # Apply full screen mode settings
    if ($InputObject.FullScreen) {
        Write-Verbose "Applying full screen mode settings"
        $rdp = $rdp.Replace('screen mode id:i:1', 'screen mode id:i:2')
        $rdp = $rdp.Replace('connection type:i:7', 'connection type:i:3')
        $rdp = $rdp.Replace('authentication level:i:2', 'authentication level:i:0')
        # Set window position to 0 for full screen
        $rdp = $rdp.Replace('${x1}', 0)
        $rdp = $rdp.Replace('${y1}', 0)
        $rdp = $rdp.Replace('${x2}', 0)
        $rdp = $rdp.Replace('${y2}', 0)
    }

    return $rdp
}
