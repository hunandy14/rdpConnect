#Requires -Version 5.1

<#
.SYNOPSIS
    RdpConnect PowerShell Module (Development Loader)

.DESCRIPTION
    This file is used during module development. It dot-sources all function
    files from src/Private and src/Public directories.

    For production use, run build.ps1 to create optimized versions:
    - build/Module/RdpConnect: Standard multi-file module
    - build/Merged/RdpConnect: Single-file module (faster loading)
    - build/Standalone/rdpConnect.ps1: Standalone script (no installation)

.NOTES
    Module: RdpConnect
    Author: hunandy14
    Version: 2.0.0
    GitHub: https://github.com/hunandy14/rdpConnect
#>

# Module root path
$ModuleRoot = $PSScriptRoot

Write-Verbose "Loading RdpConnect module from: $ModuleRoot"

# Load Private functions (internal helpers)
$PrivatePath = Join-Path $ModuleRoot 'src/Private'
if (Test-Path $PrivatePath) {
    $PrivateFunctions = Get-ChildItem "$PrivatePath/*.ps1" -ErrorAction SilentlyContinue

    foreach ($function in $PrivateFunctions) {
        Write-Verbose "  Loading Private: $($function.Name)"
        try {
            . $function.FullName
        }
        catch {
            Write-Error "Failed to load private function $($function.Name): $_"
        }
    }

    Write-Verbose "Loaded $($PrivateFunctions.Count) private functions"
}

# Load Public functions (exported commands)
$PublicPath = Join-Path $ModuleRoot 'src/Public'
if (Test-Path $PublicPath) {
    $PublicFunctions = Get-ChildItem "$PublicPath/*.ps1" -ErrorAction SilentlyContinue

    foreach ($function in $PublicFunctions) {
        Write-Verbose "  Loading Public: $($function.Name)"
        try {
            . $function.FullName
        }
        catch {
            Write-Error "Failed to load public function $($function.Name): $_"
        }
    }

    Write-Verbose "Loaded $($PublicFunctions.Count) public functions"

    # Export public functions
    $functionNames = $PublicFunctions | ForEach-Object { $_.BaseName }
    Export-ModuleMember -Function $functionNames
}

# Create aliases for backward compatibility
Write-Verbose "Creating backward compatibility aliases"
Set-Alias -Name rdpConnect -Value Connect-RdpSession
Set-Alias -Name rdpMgr -Value Show-RdpServerList
Set-Alias -Name Install -Value Install-RdpConnectModule
Set-Alias -Name WrapUp2Bat -Value Export-RdpBatchLauncher

# Export aliases
Export-ModuleMember -Alias 'rdpConnect', 'rdpMgr', 'Install', 'WrapUp2Bat'

Write-Verbose "RdpConnect module loaded successfully"
