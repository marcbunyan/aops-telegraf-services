<#
.SYNOPSIS
Exports an alphabetically sorted list of service display names (with spaces
replaced by underscores) and service names on a Windows machine to a CSV file
without quotation marks, you can use this CSV file as the import of services for monitoring with telegraf.

.DESCRIPTION
This script retrieves the Display Name and Service Name for all services
on the local computer. It converts spaces in the Display Name to underscores,
sorts the services alphabetically by this modified Display Name, and exports
the sorted list to a CSV file, ensuring that no quotation marks are used
around the data fields.

.PARAMETER OutputPath
The path and filename for the output CSV file. If not specified,
a filename will be generated in the current directory.

.EXAMPLE
.\Export-Services-NoQuotes.ps1 -OutputPath "C:\Temp\NoQuotesServices.csv"

.EXAMPLE
.\Export-Services-NoQuotes.ps1
#>
param(
    [Parameter(Mandatory=$false)]
    [string]$OutputPath
)

# Determine the output path
if (-not $OutputPath) {
    $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $OutputPath = Join-Path -Path $PWD -ChildPath "NoQuotesServices_$Timestamp.csv"
}

# Get all services, modify DisplayName, select properties, and then sort
$Services = Get-Service | ForEach-Object {
    [PSCustomObject]@{
        DisplayName = $_.DisplayName -replace ' ', '_'
        Name        = $_.Name
    }
} | Sort-Object DisplayName

# Export the sorted service information to a CSV file without type information and with no quotes
$Services | Export-Csv -Path $OutputPath -NoTypeInformation -UseQuotes Never

Write-Host "Alphabetically sorted service display names (with underscores) and names have been exported to: '$OutputPath' without quotation marks."
