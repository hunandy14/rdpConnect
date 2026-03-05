#Requires -Version 5.1

<#
.SYNOPSIS
    Installs RdpConnect module to PowerShell PROFILE.

.DESCRIPTION
    Downloads the RdpConnect module from GitHub and configures it to load
    automatically in PowerShell sessions by adding an import statement to
    the PowerShell PROFILE file.

    Two installation modes:
    - Interactive (default): Copies import statement to clipboard and opens PROFILE in Notepad
    - Automatic (-ForceAppend): Automatically adds import statement to PROFILE

.PARAMETER ForceAppend
    Automatically append the import statement to PROFILE without user interaction.
    Default: $false (interactive mode)

.OUTPUTS
    None. Downloads module files and updates PROFILE configuration.

.EXAMPLE
    Install-RdpConnectModule
    Downloads module and opens PROFILE for manual editing.
    Import statement is copied to clipboard.

.EXAMPLE
    Install-RdpConnectModule -ForceAppend
    Downloads module and automatically adds import statement to PROFILE.

.NOTES
    Alias: Install (for backward compatibility)

    Downloaded files location: Same directory as $PROFILE
    - rdpConnect.ps1: Standalone script version
    - Template.rdp: RDP template file

    The module will be loaded in all future PowerShell sessions.

.LINK
    https://github.com/hunandy14/rdpConnect
#>
function Install-RdpConnectModule {
    [CmdletBinding()]
    param (
        [Parameter()]
        [switch]$ForceAppend
    )

    Write-Host "Installing RdpConnect module..." -ForegroundColor Cyan

    # Ensure PROFILE exists
    if (-not (Test-Path -Path $PROFILE)) {
        Write-Verbose "Creating PowerShell PROFILE: $PROFILE"
        New-Item -ItemType File -Path $PROFILE -Force | Out-Null
    }

    $profileDir = (Get-Item $PROFILE).Directory
    Write-Verbose "Installation directory: $profileDir"

    # Download Standalone version from GitHub
    try {
        # Main script (Standalone version)
        $mainUrl = "https://raw.githubusercontent.com/hunandy14/rdpConnect/master/build/Standalone/rdpConnect.ps1"
        $mainDest = Join-Path $profileDir "rdpConnect.ps1"

        Write-Host "Downloading rdpConnect.ps1..." -ForegroundColor Yellow
        Write-Verbose "URL: $mainUrl"
        Write-Verbose "Destination: $mainDest"

        try {
            Invoke-WebRequest $mainUrl -OutFile $mainDest -ErrorAction Stop
            Write-Host "  Downloaded: rdpConnect.ps1" -ForegroundColor Green
        }
        catch {
            # Fallback: Try master branch root (for backward compatibility)
            $fallbackUrl = "https://raw.githubusercontent.com/hunandy14/rdpConnect/master/rdpConnect.ps1"
            Write-Warning "Primary URL failed, trying fallback: $fallbackUrl"
            Invoke-WebRequest $fallbackUrl -OutFile $mainDest -ErrorAction Stop
            Write-Host "  Downloaded: rdpConnect.ps1 (fallback)" -ForegroundColor Green
        }

        # Template file (optional, standalone version has embedded template)
        $templateUrl = "https://raw.githubusercontent.com/hunandy14/rdpConnect/master/Template.rdp"
        $templateDest = Join-Path $profileDir "Template.rdp"

        Write-Host "Downloading Template.rdp..." -ForegroundColor Yellow
        try {
            Invoke-WebRequest $templateUrl -OutFile $templateDest -ErrorAction SilentlyContinue
            Write-Host "  Downloaded: Template.rdp" -ForegroundColor Green
        }
        catch {
            Write-Verbose "Template.rdp download failed (not critical, using embedded template)"
        }
    }
    catch {
        throw "Failed to download module files: $_"
    }

    # Configure PROFILE to import module
    $importStatement = ". `"$mainDest`""
    Write-Verbose "Import statement: $importStatement"

    if ($ForceAppend) {
        # Automatic mode: Append to PROFILE if not already present
        $profileContent = Get-Content $PROFILE -ErrorAction SilentlyContinue
        $alreadyExists = $profileContent | Where-Object { $_ -eq $importStatement }

        if (-not $alreadyExists) {
            Add-Content $PROFILE "`n$importStatement"
            Write-Host "`nModule import added to PROFILE." -ForegroundColor Green
        }
        else {
            Write-Host "`nModule import already exists in PROFILE." -ForegroundColor Yellow
        }

        Write-Host "Installation complete!" -ForegroundColor Green
        Write-Host "Restart PowerShell or run: . `$PROFILE" -ForegroundColor Cyan
    }
    else {
        # Interactive mode: Copy to clipboard and open PROFILE
        Set-Clipboard $importStatement
        Write-Host "`nImport statement copied to clipboard:" -ForegroundColor Green
        Write-Host "  $importStatement" -ForegroundColor White

        Write-Host "`nOpening PROFILE in Notepad..." -ForegroundColor Yellow
        Write-Host "Please paste the import statement at the end of the file." -ForegroundColor Yellow
        Start-Sleep -Milliseconds 500
        notepad.exe $PROFILE
    }

    Write-Verbose "Installation completed successfully"
}
