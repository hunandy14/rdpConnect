#Requires -Version 5.1

function Save-RdpData {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]$Data,

        [Parameter(Mandatory)]
        [string]$Path
    )

    # Update order fields to match current array positions
    for ($i = 0; $i -lt $Data.categories.Count; $i++) {
        $Data.categories[$i].order = $i
        for ($j = 0; $j -lt $Data.categories[$i].hosts.Count; $j++) {
            $Data.categories[$i].hosts[$j].order = $j
        }
    }

    $json = $Data | ConvertTo-Json -Depth 10
    $tmpPath = "$Path.tmp"

    try {
        [IO.File]::WriteAllText($tmpPath, $json, [Text.Encoding]::UTF8)
        Move-Item -Path $tmpPath -Destination $Path -Force
    }
    catch {
        if (Test-Path $tmpPath) { Remove-Item $tmpPath -Force }
        throw "Failed to save RDP data: $_"
    }
}
