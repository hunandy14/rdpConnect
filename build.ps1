#Requires -Version 5.1

<#
.SYNOPSIS
    Build script for RdpConnect module

.DESCRIPTION
    Builds RdpConnect module in three different modes:
    - Module: Standard multi-file module (for PowerShell Gallery and development)
    - Merged: Single-file module (optimized for fast loading)
    - Standalone: Standalone script with embedded template (for offline use)

.PARAMETER BuildMode
    Build mode: Module, Merged, Standalone, or All
    Default: All

.PARAMETER Version
    Module version number. If not specified, attempts to get from git tag.
    Default: Auto-detect or 2.0.0

.PARAMETER OutputPath
    Output directory for build artifacts.
    Default: .\build

.PARAMETER Clean
    Remove existing build directory before building.

.EXAMPLE
    .\build.ps1
    Builds all three modes with auto-detected version.

.EXAMPLE
    .\build.ps1 -BuildMode Module -Version 2.0.1
    Builds only the standard module with version 2.0.1.

.EXAMPLE
    .\build.ps1 -Clean
    Cleans build directory and rebuilds all modes.

.NOTES
    Author: hunandy14
    Project: https://github.com/hunandy14/rdpConnect
#>

[CmdletBinding()]
param (
    [Parameter()]
    [ValidateSet('Module', 'Merged', 'Standalone', 'All')]
    [string]$BuildMode = 'All',

    [Parameter()]
    [string]$Version,

    [Parameter()]
    [string]$OutputPath = '.\build',

    [Parameter()]
    [switch]$Clean
)

# ============================================================================
# Configuration
# ============================================================================

$Script:Config = @{
    ModuleName        = 'RdpConnect'
    RootPath          = $PSScriptRoot
    SrcPath           = Join-Path $PSScriptRoot 'src'
    OutputPath        = $OutputPath
    Author            = 'hunandy14'
    CompanyName       = 'Personal'
    Description       = 'RDP connection manager with automatic resolution scaling and password management'
    ProjectUri        = 'https://github.com/hunandy14/rdpConnect'
    LicenseUri        = 'https://github.com/hunandy14/rdpConnect/blob/master/LICENSE'
    PowerShellVersion = '5.1'
    GUID              = 'ef073fd7-239d-47e0-bb77-7d862cb14783'
}

# ============================================================================
# Helper Functions
# ============================================================================

function Get-BuildVersion {
    <#
    .SYNOPSIS
        Gets the build version number.
    .DESCRIPTION
        Priority: Manual parameter > Git tag > Default 2.0.0
    #>
    if ($Version) {
        Write-Verbose "Using manual version: $Version"
        return $Version
    }

    # Try to get from git tag
    try {
        $gitTag = git describe --tags --abbrev=0 2>$null
        if ($gitTag -and $gitTag -match '^\d+\.\d+\.\d+$') {
            Write-Verbose "Using git tag version: $gitTag"
            return $gitTag
        }
    }
    catch {
        Write-Verbose "Git tag not available"
    }

    # Default version
    Write-Verbose "Using default version: 2.0.0"
    return '2.0.0'
}

function Get-FunctionFiles {
    <#
    .SYNOPSIS
        Gets all function files from Public or Private folder.
    #>
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Public', 'Private')]
        [string]$Type
    )

    $path = Join-Path $Config.SrcPath $Type
    if (Test-Path $path) {
        Get-ChildItem -Path $path -Filter '*.ps1' -File | Sort-Object Name
    }
}

function Merge-FunctionContent {
    <#
    .SYNOPSIS
        Merges multiple function files into single content.
    .DESCRIPTION
        Removes #Requires statements and extra blank lines.
    #>
    param(
        [Parameter(Mandatory)]
        [System.IO.FileInfo[]]$Files
    )

    $merged = @()

    foreach ($file in $Files) {
        Write-Verbose "  Merging: $($file.Name)"

        $content = Get-Content $file.FullName -Raw -Encoding UTF8

        # Remove #Requires statements (will be added at module level)
        $content = $content -replace '(?m)^#Requires.*$', ''

        # Remove excessive blank lines (3+ consecutive blank lines -> 2)
        $content = $content -replace '(?m)(\r?\n){3,}', "`n`n"

        # Trim leading/trailing whitespace
        $content = $content.Trim()

        $merged += $content
    }

    return ($merged -join "`n`n")
}

function Write-ModuleManifest {
    <#
    .SYNOPSIS
        Creates a module manifest file (.psd1).
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$RootModule,

        [Parameter(Mandatory)]
        [string]$Version,

        [Parameter(Mandatory)]
        [string[]]$FunctionsToExport
    )

    $manifestContent = @"
@{
    RootModule = '$RootModule'
    ModuleVersion = '$Version'
    GUID = '$($Config.GUID)'
    Author = '$($Config.Author)'
    CompanyName = '$($Config.CompanyName)'
    Copyright = '(c) $(Get-Date -Format yyyy) $($Config.Author). All rights reserved.'
    Description = '$($Config.Description)'
    PowerShellVersion = '$($Config.PowerShellVersion)'

    FunctionsToExport = @(
        $(($FunctionsToExport | ForEach-Object { "'$_'" }) -join ",`n        ")
    )

    CmdletsToExport = @()
    VariablesToExport = @()

    AliasesToExport = @('rdpConnect', 'rdpMgr', 'Install', 'WrapUp2Bat')

    PrivateData = @{
        PSData = @{
            Tags = @('RDP', 'RemoteDesktop', 'Windows', 'Automation', 'DPI', 'Scaling')
            ProjectUri = '$($Config.ProjectUri)'
            LicenseUri = '$($Config.LicenseUri)'
        }
    }
}
"@

    $manifestContent | Set-Content $Path -Encoding UTF8
    Write-Verbose "Created manifest: $Path"
}

# ============================================================================
# Build Functions
# ============================================================================

function Build-StandardModule {
    <#
    .SYNOPSIS
        Builds standard multi-file module.
    #>
    param([string]$Version)

    Write-Host "`n[1/3] Building Standard Module..." -ForegroundColor Cyan

    $moduleDir = Join-Path $Config.OutputPath 'Module' $Config.ModuleName

    # Clean and create directory
    if (Test-Path $moduleDir) {
        Remove-Item $moduleDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $moduleDir -Force | Out-Null

    # Create subdirectories
    $publicDir = New-Item -ItemType Directory -Path "$moduleDir\Public" -Force
    $privateDir = New-Item -ItemType Directory -Path "$moduleDir\Private" -Force
    $resourceDir = New-Item -ItemType Directory -Path "$moduleDir\Resources" -Force

    # Copy function files
    $publicFiles = Get-FunctionFiles -Type Public
    $privateFiles = Get-FunctionFiles -Type Private

    if ($publicFiles) {
        $publicFiles | Copy-Item -Destination $publicDir
        Write-Verbose "Copied $($publicFiles.Count) public functions"
    }

    if ($privateFiles) {
        $privateFiles | Copy-Item -Destination $privateDir
        Write-Verbose "Copied $($privateFiles.Count) private functions"
    }

    # Copy resources
    $templatePath = Join-Path $Config.SrcPath 'Resources\Template.rdp'
    if (Test-Path $templatePath) {
        Copy-Item $templatePath -Destination $resourceDir
        Write-Verbose "Copied Template.rdp"
    }

    # Create module file (.psm1)
    $moduleContent = @"
#Requires -Version 5.1

# RdpConnect Module
# Auto-generated by build.ps1

`$ModuleRoot = `$PSScriptRoot

# Load Private functions
`$PrivatePath = Join-Path `$ModuleRoot 'Private'
if (Test-Path `$PrivatePath) {
    Get-ChildItem "`$PrivatePath\*.ps1" | ForEach-Object { . `$_.FullName }
}

# Load Public functions
`$PublicPath = Join-Path `$ModuleRoot 'Public'
if (Test-Path `$PublicPath) {
    Get-ChildItem "`$PublicPath\*.ps1" | ForEach-Object { . `$_.FullName }
}

# Backward compatibility aliases
Set-Alias -Name rdpConnect -Value Connect-RdpSession
Set-Alias -Name rdpMgr -Value Show-RdpServerList
Set-Alias -Name Install -Value Install-RdpConnectModule
Set-Alias -Name WrapUp2Bat -Value Export-RdpBatchLauncher

Export-ModuleMember -Function * -Alias *
"@

    $moduleContent | Set-Content "$moduleDir\$($Config.ModuleName).psm1" -Encoding UTF8

    # Create manifest
    $exportedFunctions = $publicFiles | ForEach-Object { $_.BaseName }
    Write-ModuleManifest -Path "$moduleDir\$($Config.ModuleName).psd1" `
        -RootModule "$($Config.ModuleName).psm1" `
        -Version $Version `
        -FunctionsToExport $exportedFunctions

    Write-Host "  ✓ Standard Module: $moduleDir" -ForegroundColor Green
}

function Build-MergedModule {
    <#
    .SYNOPSIS
        Builds merged single-file module.
    #>
    param([string]$Version)

    Write-Host "`n[2/3] Building Merged Module..." -ForegroundColor Cyan

    $moduleDir = Join-Path $Config.OutputPath 'Merged' $Config.ModuleName

    # Clean and create directory
    if (Test-Path $moduleDir) {
        Remove-Item $moduleDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $moduleDir -Force | Out-Null

    # Get function files
    $privateFiles = Get-FunctionFiles -Type Private
    $publicFiles = Get-FunctionFiles -Type Public

    # Merge content
    Write-Verbose "Merging private functions..."
    $privateContent = if ($privateFiles) {
        Merge-FunctionContent -Files $privateFiles
    } else { '' }

    Write-Verbose "Merging public functions..."
    $publicContent = if ($publicFiles) {
        Merge-FunctionContent -Files $publicFiles
    } else { '' }

    # Create merged module file
    $moduleContent = @"
#Requires -Version 5.1

# ============================================================================
# RdpConnect Module (Merged)
# Auto-generated by build.ps1
# Version: $Version
# ============================================================================

# ----------------------------------------------------------------------------
# Private Functions
# ----------------------------------------------------------------------------

$privateContent

# ----------------------------------------------------------------------------
# Public Functions
# ----------------------------------------------------------------------------

$publicContent

# ----------------------------------------------------------------------------
# Aliases (Backward Compatibility)
# ----------------------------------------------------------------------------

Set-Alias -Name rdpConnect -Value Connect-RdpSession
Set-Alias -Name rdpMgr -Value Show-RdpServerList
Set-Alias -Name Install -Value Install-RdpConnectModule
Set-Alias -Name WrapUp2Bat -Value Export-RdpBatchLauncher

Export-ModuleMember -Function * -Alias *
"@

    $moduleContent | Set-Content "$moduleDir\$($Config.ModuleName).psm1" -Encoding UTF8

    # Copy Template.rdp as external resource
    $templatePath = Join-Path $Config.SrcPath 'Resources\Template.rdp'
    if (Test-Path $templatePath) {
        Copy-Item $templatePath -Destination $moduleDir
    }

    # Create manifest
    $exportedFunctions = $publicFiles | ForEach-Object { $_.BaseName }
    Write-ModuleManifest -Path "$moduleDir\$($Config.ModuleName).psd1" `
        -RootModule "$($Config.ModuleName).psm1" `
        -Version $Version `
        -FunctionsToExport $exportedFunctions

    $fileSize = [math]::Round((Get-Item "$moduleDir\$($Config.ModuleName).psm1").Length / 1KB, 2)
    Write-Host "  ✓ Merged Module: $moduleDir ($fileSize KB)" -ForegroundColor Green
}

function Build-StandaloneScript {
    <#
    .SYNOPSIS
        Builds standalone script with embedded template.
    #>
    param([string]$Version)

    Write-Host "`n[3/3] Building Standalone Script..." -ForegroundColor Cyan

    $outputDir = Join-Path $Config.OutputPath 'Standalone'

    # Clean and create directory
    if (Test-Path $outputDir) {
        Remove-Item $outputDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

    # Read Template.rdp for embedding
    $templatePath = Join-Path $Config.SrcPath 'Resources\Template.rdp'
    $templateContent = Get-Content $templatePath -Raw -Encoding UTF8

    # Get function files
    $privateFiles = Get-FunctionFiles -Type Private
    $publicFiles = Get-FunctionFiles -Type Public

    # Merge content
    $privateContent = if ($privateFiles) {
        Merge-FunctionContent -Files $privateFiles
    } else { '' }

    $publicContent = if ($publicFiles) {
        Merge-FunctionContent -Files $publicFiles
    } else { '' }

    # Create standalone script
    $standaloneContent = @"
#Requires -Version 5.1

<#
.SYNOPSIS
    RdpConnect - Standalone Script (No installation required)

.DESCRIPTION
    All functions are embedded in this single file.

    Usage:
      . .\rdpConnect.ps1
      Connect-RdpSession '192.168.1.100'

.VERSION
    $Version

.AUTHOR
    $($Config.Author)

.LINK
    $($Config.ProjectUri)
#>

# ============================================================================
# Embedded RDP Template
# ============================================================================

`$Script:EmbeddedRdpTemplate = @'
$templateContent
'@

# ============================================================================
# Private Functions
# ============================================================================

$privateContent

# ============================================================================
# Public Functions
# ============================================================================

$publicContent

# ============================================================================
# Aliases (Backward Compatibility)
# ============================================================================

Set-Alias -Name rdpConnect -Value Connect-RdpSession -Scope Global
Set-Alias -Name rdpMgr -Value Show-RdpServerList -Scope Global
Set-Alias -Name Install -Value Install-RdpConnectModule -Scope Global
Set-Alias -Name WrapUp2Bat -Value Export-RdpBatchLauncher -Scope Global

# ============================================================================
# Module loaded
# ============================================================================

Write-Host "RdpConnect $Version loaded. Use Connect-RdpSession to start." -ForegroundColor Green
"@

    $standaloneContent | Set-Content "$outputDir\rdpConnect.ps1" -Encoding UTF8

    # Create BAT launcher
    Build-BatLauncher -OutputDir $outputDir

    # Copy sample CSV
    $csvPath = Join-Path $Config.RootPath 'rdpList.csv'
    if (Test-Path $csvPath) {
        Copy-Item $csvPath -Destination $outputDir
    }
    else {
        # Create sample CSV if doesn't exist
        $sampleCsv = @"
Description,IP,AC,PW
Server1,192.168.1.100,administrator,
Server2,192.168.1.101,admin,
"@
        $sampleCsv | Set-Content "$outputDir\rdpList.csv" -Encoding UTF8
    }

    $fileSize = [math]::Round((Get-Item "$outputDir\rdpConnect.ps1").Length / 1KB, 2)
    Write-Host "  ✓ Standalone Script: $outputDir ($fileSize KB)" -ForegroundColor Green
}

function Build-BatLauncher {
    <#
    .SYNOPSIS
        Creates BAT launcher file.
    #>
    param([string]$OutputDir)

    $batContent = @'
@echo off
setlocal EnableDelayedExpansion

rem ============================================================================
rem rdpMgr.bat - RDP Manager Launcher
rem Auto-generated by build.ps1
rem ============================================================================

set "ScriptPath=%~dp0rdpConnect.ps1"

if not exist "%ScriptPath%" (
    echo ERROR: rdpConnect.ps1 not found!
    echo Please ensure rdpConnect.ps1 is in the same directory as this BAT file.
    pause
    exit /b 1
)

rem Launch PowerShell and execute Show-RdpServerList
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
    "Set-Location '%~dp0'; . '%ScriptPath%'; Show-RdpServerList -Path '.\rdpList.csv'"

exit /b %ERRORLEVEL%
'@

    $batContent | Set-Content "$OutputDir\rdpMgr.bat" -Encoding ASCII
    Write-Verbose "Created BAT launcher: $OutputDir\rdpMgr.bat"
}

# ============================================================================
# Main Execution
# ============================================================================

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  RdpConnect Module Build Script" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# Get version
$buildVersion = Get-BuildVersion
Write-Host "`nBuild Version: $buildVersion" -ForegroundColor Yellow
Write-Host "Build Mode: $BuildMode" -ForegroundColor Yellow

# Clean build directory if requested
if ($Clean -and (Test-Path $Config.OutputPath)) {
    Write-Host "`nCleaning build directory..." -ForegroundColor Yellow
    Remove-Item $Config.OutputPath -Recurse -Force
}

# Ensure output directory exists
if (-not (Test-Path $Config.OutputPath)) {
    New-Item -ItemType Directory -Path $Config.OutputPath -Force | Out-Null
}

# Execute build
try {
    switch ($BuildMode) {
        'Module' {
            Build-StandardModule -Version $buildVersion
        }
        'Merged' {
            Build-MergedModule -Version $buildVersion
        }
        'Standalone' {
            Build-StandaloneScript -Version $buildVersion
        }
        'All' {
            Build-StandardModule -Version $buildVersion
            Build-MergedModule -Version $buildVersion
            Build-StandaloneScript -Version $buildVersion
        }
    }

    Write-Host "`n============================================" -ForegroundColor Cyan
    Write-Host "  Build Completed Successfully!" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "`nOutput Directory: $($Config.OutputPath)" -ForegroundColor White
}
catch {
    Write-Host "`n============================================" -ForegroundColor Red
    Write-Host "  Build Failed!" -ForegroundColor Red
    Write-Host "============================================" -ForegroundColor Red
    Write-Error $_
    exit 1
}
