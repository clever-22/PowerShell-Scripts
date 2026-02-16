<#
.SYNOPSIS
    Displays all ScreenConnect Client installations and their GUIDs
.DESCRIPTION
    Searches the Windows registry to find all installed ScreenConnect Client instances.
    Extracts and displays the GUID (fingerprint) for each client found.
    Checks both 64-bit and 32-bit registry locations.
#>

$registryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

Write-Host "=== ScreenConnect Clients Found ===" -ForegroundColor Cyan
Write-Host ""

$found = $false

foreach ($path in $registryPaths) {
    $keys = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue | Where-Object {
        $_.DisplayName -like "*ScreenConnect Client*"
    }

    foreach ($key in $keys) {
        $found = $true
        $displayName = $key.DisplayName
        
        # Extract GUID from DisplayName (value in parentheses)
        if ($displayName -match '\((.+?)\)') {
            $guid = $Matches[1]
            Write-Host "Display Name: $displayName" -ForegroundColor Green
            Write-Host "GUID:         $guid" -ForegroundColor Yellow
            Write-Host ""
        }
    }
}

if (-not $found) {
    Write-Host "No ScreenConnect Clients found on this system." -ForegroundColor Red
}