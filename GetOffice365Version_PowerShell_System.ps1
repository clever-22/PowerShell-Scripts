<#
.SYNOPSIS
    Retrieves installed Microsoft Office 365 version and configuration details
.DESCRIPTION
    Queries the registry to retrieve Office 365 version number, platform (32-bit or 64-bit),
    and update channel information. Displays results in a formatted table.
#>

# 1. Get the Version Number reported to the system
$OfficePath = "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration"
$Version = (Get-ItemProperty -Path $OfficePath -ErrorAction SilentlyContinue).VersionToReport

# 2. Get the Update Channel (Monthly, Semi-Annual, etc.)
$Channel = (Get-ItemProperty -Path $OfficePath -ErrorAction SilentlyContinue).CDNBaseUrl

# 3. Get the "Bitness" (32-bit vs 64-bit)
$Bitness = (Get-ItemProperty -Path $OfficePath -ErrorAction SilentlyContinue).Platform

Write-Host "--- Microsoft Office Status ---" -ForegroundColor Cyan
Write-Host "Version Reported: $Version"
Write-Host "Platform:         $Bitness"

# Translate Channel URL to readable name
if ($Channel -like "*491d92d0*") { Write-Host "Update Channel:   Current Channel" }
elseif ($Channel -like "*55336b38*") { Write-Host "Update Channel:   Monthly Enterprise" }
elseif ($Channel -like "*7ffbc6fb*") { Write-Host "Update Channel:   Semi-Annual Enterprise" }
else { Write-Host "Update Channel:   $Channel" }