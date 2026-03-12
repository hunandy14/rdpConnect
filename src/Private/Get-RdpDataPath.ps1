#Requires -Version 5.1

function Get-RdpDataPath {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$BasePath
    )

    if (-not $BasePath) {
        # Priority 1: Global variable
        if ($Global:__rdpMgrPath__) {
            $BasePath = $Global:__rdpMgrPath__
            # If it points to a file, use its directory
            if ($BasePath -match '\.(json|csv)$') {
                $BasePath = Split-Path $BasePath -Parent
            }
        }
        # Priority 2: Script root (module context)
        elseif ($PSScriptRoot) {
            $privatePath = $PSScriptRoot
            $srcPath = Split-Path $privatePath -Parent
            $BasePath = Split-Path $srcPath -Parent
        }
        # Priority 3: Current directory
        else {
            $BasePath = (Get-Location).Path
        }
    }

    @{
        DataPath     = Join-Path $BasePath 'rdpList.json'
        SettingsPath = Join-Path $BasePath 'rdpSettings.json'
        BasePath     = $BasePath
    }
}
