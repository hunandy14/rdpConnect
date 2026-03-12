#Requires -Version 5.1

function Save-RdpSettings {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]$Settings,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $json = $Settings | ConvertTo-Json -Depth 3
    $tmpPath = "$Path.tmp"

    try {
        [IO.File]::WriteAllText($tmpPath, $json, [Text.Encoding]::UTF8)
        Move-Item -Path $tmpPath -Destination $Path -Force
    }
    catch {
        if (Test-Path $tmpPath) { Remove-Item $tmpPath -Force }
        Write-Warning "Failed to save settings: $_"
    }
}
