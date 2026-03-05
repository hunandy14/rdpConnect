#Requires -Version 5.1

<#
.SYNOPSIS
    Displays a server list from CSV and connects to selected server.

.DESCRIPTION
    Reads an RDP server list from a CSV file, displays it in a graphical grid view,
    and connects to the selected server using Connect-RdpSession.

    CSV file must contain columns:
    - Description: Server description
    - IP: Server IP address or hostname
    - AC: Account (username)
    - PW: Password

    Supports encoding configuration for international characters (Chinese, Japanese, etc.).

.PARAMETER Path
    Path to the CSV file containing server list.
    Default search order:
    1. Global variable: $Global:__rdpMgrPath__
    2. Script root: $PSScriptRoot\rdpList.csv
    3. Current directory: .\rdpList.csv

.PARAMETER Ratio
    Aspect ratio for windowed connection mode.
    Default: 16/10
    Ignored if -FullScreen is used.

.PARAMETER FullScreen
    Connect in full screen mode.

.PARAMETER Edit
    Open the CSV file in Notepad for editing instead of showing the list.

.PARAMETER Encoding
    Character encoding code page for CSV file.
    Default: System default code page ([Text.Encoding]::Default.CodePage)
    Common values:
    - 65001: UTF-8
    - 950: Big5 (Traditional Chinese)
    - 936: GBK (Simplified Chinese)
    - 932: Shift-JIS (Japanese)

    Can be overridden by global variable: $Global:__rdpMgrEncoding__

.OUTPUTS
    None. Launches RDP connection to selected server.

.EXAMPLE
    Show-RdpServerList
    Shows server list from default location with 16:10 ratio.

.EXAMPLE
    Show-RdpServerList -FullScreen
    Shows server list and connects in full screen mode.

.EXAMPLE
    Show-RdpServerList -Path 'C:\Servers\production.csv' -Ratio (16/9)
    Uses custom CSV file and 16:9 ratio.

.EXAMPLE
    Show-RdpServerList -Edit
    Opens the CSV file in Notepad for editing.

.EXAMPLE
    $Global:__rdpMgrPath__ = 'C:\MyServers\list.csv'
    $Global:__rdpMgrEncoding__ = 65001
    Show-RdpServerList
    Uses global variables to configure path and encoding.

.EXAMPLE
    Show-RdpServerList -Encoding 65001
    Uses UTF-8 encoding to read the CSV file.

.NOTES
    Alias: rdpMgr (for backward compatibility)

    Global variable configuration:
    - $Global:__rdpMgrPath__: Default CSV path
    - $Global:__rdpMgrEncoding__: Default encoding code page
#>
function Show-RdpServerList {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$Path,

        [Parameter()]
        [double]$Ratio = (16 / 10),

        [Parameter()]
        [switch]$FullScreen,

        [Parameter()]
        [switch]$Edit,

        [Parameter()]
        [int]$Encoding = (([Text.Encoding]::Default).CodePage)
    )

    # Determine CSV file path
    if (-not $Path) {
        # Priority 1: Global variable
        if ($Global:__rdpMgrPath__) {
            $Path = $Global:__rdpMgrPath__
            Write-Verbose "Using global path: $Path"
        }
        # Priority 2: Script root (module context)
        elseif ($PSScriptRoot) {
            # Try to find module root (go up from src/Public to root)
            $publicPath = $PSScriptRoot
            $srcPath = Split-Path $publicPath -Parent
            $moduleRoot = Split-Path $srcPath -Parent

            $Path = Join-Path $moduleRoot 'rdpList.csv'
            Write-Verbose "Checking module root: $Path"

            # Fallback 1: Check src directory
            if (-not (Test-Path $Path)) {
                $Path = Join-Path $srcPath 'rdpList.csv'
                Write-Verbose "Fallback to src directory: $Path"
            }

            # Fallback 2: Check script root itself (Public directory)
            if (-not (Test-Path $Path)) {
                $Path = Join-Path $PSScriptRoot 'rdpList.csv'
                Write-Verbose "Fallback to script root: $Path"
            }
        }
        # Priority 3: Current directory
        else {
            $Path = '.\rdpList.csv'
            Write-Verbose "Using current directory: $Path"
        }
    }

    Write-Verbose "CSV file path: $Path"

    # Edit mode: Open CSV in Notepad
    if ($Edit) {
        if (Test-Path $Path) {
            Write-Host "Opening CSV file in Notepad: $Path" -ForegroundColor Cyan
            notepad.exe $Path
        }
        else {
            Write-Warning "CSV file not found: $Path"
            Write-Host "Create a new file with columns: Description,IP,AC,PW" -ForegroundColor Yellow
            notepad.exe $Path  # Opens as new file
        }
        return
    }

    # Verify CSV file exists
    if (-not (Test-Path $Path)) {
        throw "Server list CSV file not found: $Path`nCreate it with columns: Description,IP,AC,PW"
    }

    # Determine encoding (global variable override)
    if ($Global:__rdpMgrEncoding__) {
        $Encoding = $Global:__rdpMgrEncoding__
        Write-Verbose "Using global encoding: $Encoding"
    }
    else {
        Write-Verbose "Using default encoding: $Encoding"
    }

    # Read CSV file with proper encoding
    try {
        $Enc = [Text.Encoding]::GetEncoding($Encoding)
        $csvContent = [IO.File]::ReadAllText($Path, $Enc)
        $list = $csvContent | ConvertFrom-Csv
        Write-Verbose "Loaded $($list.Count) servers from CSV"
    }
    catch {
        throw "Failed to read CSV file: $_"
    }

    # Verify CSV has required columns
    if ($list.Count -eq 0) {
        throw "CSV file is empty: $Path"
    }

    $firstItem = $list[0]
    $requiredColumns = @('Description', 'IP', 'AC', 'PW')
    $missingColumns = $requiredColumns | Where-Object { -not $firstItem.PSObject.Properties.Name.Contains($_) }

    if ($missingColumns) {
        throw "CSV file missing required columns: $($missingColumns -join ', ')`nRequired: $($requiredColumns -join ', ')"
    }

    # Show server list in grid view for selection
    Write-Host "Select a server from the list..." -ForegroundColor Cyan
    $Serv = $list | Out-GridView -PassThru -Title 'RdpConnect - Select Server'

    # Connect to selected server
    if ($Serv) {
        Write-Host "Connecting to: $($Serv.Description) ($($Serv.IP))" -ForegroundColor Green

        $connectParams = @{
            IP       = $Serv.IP
            Username = $Serv.AC
        }

        # Add password if present
        if ($Serv.PW) {
            $connectParams['CopyPassWD'] = $Serv.PW
        }

        # Add connection mode
        if ($FullScreen) {
            $connectParams['FullScreen'] = $true
        }
        else {
            $connectParams['Ratio'] = $Ratio
        }

        Connect-RdpSession @connectParams
    }
    else {
        Write-Host "No server selected. Connection cancelled." -ForegroundColor Yellow
    }
}
