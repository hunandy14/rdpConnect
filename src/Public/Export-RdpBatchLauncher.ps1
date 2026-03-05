#Requires -Version 5.1

<#
.SYNOPSIS
    Exports a standalone BAT launcher for offline RDP management.

.DESCRIPTION
    Downloads and packages the RdpConnect functionality into a standalone
    BAT file that can be used offline without PowerShell module installation.

    The generated BAT file:
    - Contains embedded PowerShell script
    - Includes RDP template
    - Launches Show-RdpServerList functionality
    - Adjusts encoding for the local system

    Also downloads the server list CSV file template.

.PARAMETER Path
    Destination folder for exported files.
    Default: User's Desktop

.OUTPUTS
    Creates two files in the specified path:
    - rdpMgr.bat: Standalone BAT launcher
    - rdpList.csv: Server list template

.EXAMPLE
    Export-RdpBatchLauncher
    Exports to Desktop (default location).

.EXAMPLE
    Export-RdpBatchLauncher -Path 'C:\RDP Tools'
    Exports to custom directory.

.NOTES
    Alias: WrapUp2Bat (for backward compatibility)

    The exported BAT file:
    - Can be used on machines without RdpConnect module installed
    - Automatically detects and uses system's default encoding
    - Contains all necessary functionality embedded
    - Ideal for enterprise environments or air-gapped systems

    The BAT file should be kept together with rdpList.csv.

.LINK
    https://github.com/hunandy14/rdpConnect
#>
function Export-RdpBatchLauncher {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$Path = [Environment]::GetFolderPath("Desktop")
    )

    Write-Host "Exporting standalone BAT launcher..." -ForegroundColor Cyan
    Write-Verbose "Export path: $Path"

    # Ensure destination directory exists
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }

    #region Helper Functions (Nested)

    <#
    .SYNOPSIS
        Removes comments and blank lines from PowerShell code.
    .DESCRIPTION
        Internal helper function to clean up code for embedding.
    #>
    function RemoveComment {
        param (
            [Parameter(Mandatory)]
            [Object]$Content,

            [String]$Mark = '#'
        )

        $lines = $Content -split "`n"

        # Remove comments (preserve those in strings) and trailing whitespace
        $cleaned = $lines -replace ("($Mark(?!')(.*?)$)|(\s+$)", "")

        # Remove blank lines
        $cleaned = $cleaned -notmatch('^\s*$')

        return [string]($cleaned -join "`n")
    }

    <#
    .SYNOPSIS
        Expands remote script references (irm/Invoke-RestMethod) inline.
    .DESCRIPTION
        Internal helper function to download and embed remote scripts.
    #>
    function ExpandIrm {
        param (
            [Parameter(Mandatory)]
            [Object]$Content,

            [String]$Encoding = 'UTF8'
        )

        # Find lines containing remote script references
        $remotelines = ($Content -split "`n") -match "bit.ly|raw.githubusercontent.com"

        foreach ($line in $remotelines) {
            try {
                # Remove Invoke-Expression/iex and execute to download
                $cleanLine = $line -replace ("(\s*\|\s*(Invoke-Expression|iex))|^iex", "")
                $expanded = Invoke-Expression $cleanLine

                # Replace the remote reference with downloaded content (cleaned)
                $Content = $Content.Replace($line, (RemoveComment $expanded))
                Write-Verbose "Expanded remote reference: $($cleanLine.Substring(0, [Math]::Min(50, $cleanLine.Length)))..."
            }
            catch {
                Write-Warning "Failed to expand line: $line"
            }
        }

        return $Content
    }

    #endregion

    try {
        # Download rdpMgr.bat from GitHub
        $batUrl = "https://raw.githubusercontent.com/hunandy14/rdpConnect/master/rdpMgr.bat"
        Write-Host "Downloading rdpMgr.bat..." -ForegroundColor Yellow
        Write-Verbose "URL: $batUrl"

        $batContent = Invoke-RestMethod $batUrl

        # Expand any remote script references
        Write-Verbose "Expanding embedded scripts..."
        $batContent = ExpandIrm $batContent

        # Convert line endings to Windows format (CRLF)
        $batContent = $batContent.Replace("`n", "`r`n")

        # Adjust encoding for local system
        $localCodePage = (PowerShell -NoProfile -Command "([Text.Encoding]::Default).CodePage")
        Write-Verbose "Local code page: $localCodePage"

        $batContent = $batContent.Replace("65001", $localCodePage)

        # Write BAT file with appropriate encoding
        $batPath = Join-Path $Path "rdpMgr.bat"
        $encoding = [Text.Encoding]::GetEncoding([int]$localCodePage)
        [IO.File]::WriteAllText($batPath, $batContent, $encoding)

        Write-Host "  Exported: rdpMgr.bat" -ForegroundColor Green
        Write-Verbose "BAT file: $batPath"

        # Download rdpList.csv template
        $csvUrl = "https://raw.githubusercontent.com/hunandy14/rdpConnect/master/rdpList.csv"
        Write-Host "Downloading rdpList.csv..." -ForegroundColor Yellow
        Write-Verbose "URL: $csvUrl"

        $csvContent = Invoke-RestMethod $csvUrl
        $csvPath = Join-Path $Path "rdpList.csv"
        [IO.File]::WriteAllText($csvPath, $csvContent, $encoding)

        Write-Host "  Exported: rdpList.csv" -ForegroundColor Green
        Write-Verbose "CSV file: $csvPath"

        # Success message
        Write-Host "`nExport completed successfully!" -ForegroundColor Green
        Write-Host "Location: $Path" -ForegroundColor Cyan
        Write-Host "`nFiles created:" -ForegroundColor White
        Write-Host "  - rdpMgr.bat    (Launcher)" -ForegroundColor Gray
        Write-Host "  - rdpList.csv   (Server list)" -ForegroundColor Gray
        Write-Host "`nUsage: Double-click rdpMgr.bat to start" -ForegroundColor Yellow

        # Open folder if on desktop
        if ($Path -eq [Environment]::GetFolderPath("Desktop")) {
            Write-Host "`nFiles saved to Desktop." -ForegroundColor Green
        }
    }
    catch {
        throw "Failed to export BAT launcher: $_"
    }
}
