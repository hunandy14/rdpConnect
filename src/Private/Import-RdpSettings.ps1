#Requires -Version 5.1

function Import-RdpSettings {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    # Default settings
    $defaults = [PSCustomObject]@{
        version        = 1
        window         = [PSCustomObject]@{ width = 700; height = 500; left = -1; top = -1 }
        connectionMode = 'windowed'
        ratio          = 1.6
        categoryState  = [PSCustomObject]@{}
    }

    if (-not (Test-Path $Path)) {
        return $defaults
    }

    try {
        $json = [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
        $settings = $json | ConvertFrom-Json

        # Merge with defaults for missing fields
        if (-not $settings.window) { $settings | Add-Member -NotePropertyName window -NotePropertyValue $defaults.window -Force }
        if (-not $settings.connectionMode) { $settings | Add-Member -NotePropertyName connectionMode -NotePropertyValue $defaults.connectionMode -Force }
        if (-not $settings.ratio) { $settings | Add-Member -NotePropertyName ratio -NotePropertyValue $defaults.ratio -Force }
        if (-not $settings.categoryState) { $settings | Add-Member -NotePropertyName categoryState -NotePropertyValue $defaults.categoryState -Force }

        return $settings
    }
    catch {
        Write-Warning "Failed to read settings, using defaults: $_"
        return $defaults
    }
}
