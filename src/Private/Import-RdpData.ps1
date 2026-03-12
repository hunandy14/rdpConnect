#Requires -Version 5.1

function Import-RdpData {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "RDP data file not found: $Path"
    }

    $json = [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
    $data = $json | ConvertFrom-Json

    # Validate structure
    if (-not $data.categories) {
        throw "Invalid rdpList.json: missing 'categories' array"
    }

    foreach ($cat in $data.categories) {
        if (-not $cat.name) { throw "Invalid category: missing 'name'" }
        if ($null -eq $cat.hosts) { $cat | Add-Member -NotePropertyName hosts -NotePropertyValue @() -Force }
        foreach ($h in $cat.hosts) {
            if (-not $h.ip) { throw "Invalid host '$($h.name)': missing 'ip'" }
            if (-not $h.accounts -or $h.accounts.Count -eq 0) {
                throw "Invalid host '$($h.name)': must have at least one account"
            }
        }
    }

    # Sort by order
    $data.categories = @($data.categories | Sort-Object { if ($null -ne $_.order) { $_.order } else { 999 } })
    foreach ($cat in $data.categories) {
        $cat.hosts = @($cat.hosts | Sort-Object { if ($null -ne $_.order) { $_.order } else { 999 } })
    }

    return $data
}
