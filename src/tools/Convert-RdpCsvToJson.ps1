#Requires -Version 5.1

<#
.SYNOPSIS
    Convert rdpList.csv to rdpList.json format.

.DESCRIPTION
    Migrates the old CSV server list (Description,IP,AC,PW) to the new JSON format
    with categories and multiple accounts support.
    All hosts are placed into a single "Default" category.

.PARAMETER CsvPath
    Path to the source CSV file. Default: .\rdpList.csv

.PARAMETER JsonPath
    Path for the output JSON file. Default: .\rdpList.json

.PARAMETER Encoding
    Character encoding code page for CSV file.
    Default: System default. Common: 65001 (UTF-8), 950 (Big5)

.EXAMPLE
    .\Convert-RdpCsvToJson.ps1
    Converts .\rdpList.csv to .\rdpList.json

.EXAMPLE
    .\Convert-RdpCsvToJson.ps1 -CsvPath C:\old\rdpList.csv -Encoding 65001
    Converts with UTF-8 encoding
#>

[CmdletBinding()]
param (
    [Parameter()]
    [string]$CsvPath = '.\rdpList.csv',

    [Parameter()]
    [string]$JsonPath = '.\rdpList.json',

    [Parameter()]
    [int]$Encoding = (([Text.Encoding]::Default).CodePage)
)

# Verify source exists
if (-not (Test-Path $CsvPath)) {
    throw "CSV file not found: $CsvPath"
}

# Check if target already exists
if (Test-Path $JsonPath) {
    $confirm = Read-Host "$JsonPath already exists. Overwrite? (y/N)"
    if ($confirm -ne 'y') {
        Write-Host "Cancelled." -ForegroundColor Yellow
        return
    }
}

# Read CSV
$enc = [Text.Encoding]::GetEncoding($Encoding)
$csvContent = [IO.File]::ReadAllText($CsvPath, $enc)
$list = $csvContent | ConvertFrom-Csv

if ($list.Count -eq 0) {
    throw "CSV file is empty: $CsvPath"
}

# Validate columns
$required = @('Description', 'IP', 'AC', 'PW')
$missing = $required | Where-Object { -not $list[0].PSObject.Properties.Name.Contains($_) }
if ($missing) {
    throw "CSV missing required columns: $($missing -join ', ')"
}

# Convert to JSON structure
$hosts = @()
for ($i = 0; $i -lt $list.Count; $i++) {
    $row = $list[$i]
    $hosts += [PSCustomObject]@{
        name           = $row.Description
        ip             = $row.IP
        order          = $i
        accounts       = @(
            [PSCustomObject]@{
                label    = if ($row.AC) { $row.AC } else { 'default' }
                username = $row.AC
                password = $row.PW
            }
        )
        defaultAccount = 0
    }
}

$data = [PSCustomObject]@{
    version    = 1
    categories = @(
        [PSCustomObject]@{
            name  = 'Default'
            order = 0
            hosts = $hosts
        }
    )
}

$json = $data | ConvertTo-Json -Depth 5
[IO.File]::WriteAllText($JsonPath, $json, [Text.Encoding]::UTF8)

Write-Host "Converted $($list.Count) hosts from CSV to JSON." -ForegroundColor Green
Write-Host "Output: $JsonPath" -ForegroundColor Cyan
