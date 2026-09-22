# CONFIGURATION
$ntfyTopic  = ""
$ntfyServer = "https://ntfy.sh"

$log = @()

$log += "-- CheckHealth --"
$checkHealth = DISM /Online /Cleanup-Image /CheckHealth 2>&1
$log += $checkHealth

$log += "-- ScanHealth --"
$scanHealth = DISM /Online /Cleanup-Image /ScanHealth 2>&1
$log += $scanHealth

$log += "-- RestoreHealth --"
$restoreHealth = DISM /Online /Cleanup-Image /RestoreHealth 2>&1
$log += $restoreHealth

$log += "-- SFC --"
$sfcOutput = ((sfc /scannow 2>&1 | Out-String) -replace "`0","")
$log += $sfcOutput -split "`r?`n"

# Remove noise
$clean = $log | Where-Object {
    $_.Trim() -ne '' -and
    $_ -notmatch 'Deployment Image Servicing|^Version:|^Image Version:'
}

# Detect corruption state
$corruptionFound = $false

if (
    $clean -match "component store corruption" -or
    $clean -match "corrupt files" -or
    $clean -match "could not be repaired" -or
    $clean -match "repairable"
) {
    $corruptionFound = $true
}

# Detect reboot required
$reboot = (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') -or
          (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')

# Build status banner
$status = @()

if ($corruptionFound) {
    $status += "❌ Corruption Found"
} else {
    $status += "✅ No Corruption Detected"
}

if ($reboot) {
    $status += "⚠️ Reboot Required"
} else {
    $status += "✅ No Reboot Required"
}

$summary = ($status -join " | ")

$body = @"
$summary

Computer: $env:COMPUTERNAME

$($clean -join "`n")
"@

# ntfy 4KB limit
if ($body.Length -gt 3900) {
    $body = $body.Substring($body.Length - 3900)
}

Invoke-RestMethod -Uri "$ntfyServer/$ntfyTopic" -Method Post `
    -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) `
    -Headers @{
        Title = "DISM/SFC - $env:COMPUTERNAME"
        Priority = if ($corruptionFound) { "high" } elseif ($reboot) { "default" } else { "low" }
    }

Write-Host $body

