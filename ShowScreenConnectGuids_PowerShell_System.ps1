<#
.SYNOPSIS
    Displays all ScreenConnect Client installations and their GUIDs
.DESCRIPTION
    Searches the Windows registry to find all installed ScreenConnect Client instances.
    Extracts and displays the installation details (Name, Version, GUID, Location) for each client found.
    Checks both 64-bit and 32-bit registry locations.
#>

$registryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)

Write-Host "=== ScreenConnect Clients Found ===" -ForegroundColor Cyan
Write-Host ""

$found = $false

foreach ($path in $registryPaths) {
    $clients = Get-ChildItem -Path $path -ErrorAction SilentlyContinue |
        Where-Object {
            ($_ | Get-ItemProperty).DisplayName -match "ScreenConnect|ConnectWise Control"
        }

    foreach ($client in $clients) {
        $found = $true
        $p = Get-ItemProperty $client.PSPath
        
        Write-Host "Name:             $($p.DisplayName)" -ForegroundColor Green
        Write-Host "Version:          $($p.DisplayVersion)" -ForegroundColor White
        Write-Host "GUID:             $($client.PSChildName)" -ForegroundColor Yellow
        Write-Host "Install Location: $($p.InstallLocation)" -ForegroundColor Cyan
        Write-Host ""
    }
}

if (-not $found) {
    Write-Host "No ScreenConnect Clients found on this system." -ForegroundColor Red
}