<#
.SYNOPSIS
    Runs DISM and SFC repairs and sends a summary to ntfy. V2 - NOT TESTED
.DESCRIPTION
    Requires administrator privileges. Runs DISM CheckHealth, ScanHealth,
    RestoreHealth, then SFC /scannow, summarizes the detected repair status,
    and posts the results to the configured ntfy topic.
#>

. {

# ============================================================
#  DISM + SFC health check -> ntfy summary
#  Paste-safe: executes as one block, no per-line prompts
# ============================================================

$NtfyTopic  = "Insertyourtopicnamehere"
$NtfyServer = "https://ntfy.sh"

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'
$ConfirmPreference     = 'None'
$InformationPreference = 'SilentlyContinue'

# --- Elevation check: fail fast instead of hanging on UAC ---
$isAdmin = ([Security.Principal.WindowsPrincipal] `
            [Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Output "ERROR: Must run elevated. Aborting."
    return
}

# --- Helper: run native cmd, strip CR progress bars + UTF-16 nulls ---
function Get-CleanOutput {
    param([scriptblock]$Command)

    $raw = (& $Command 2>&1 | Out-String) -replace "`0", ""
    $raw = $raw -replace "`r`n", "`n" -replace "`r", "`n"

    ($raw -split "`n") | ForEach-Object { $_.Trim() } | Where-Object {
        $_ -ne ''                                       -and
        $_ -notmatch '^\['                              -and
        $_ -notmatch '%'                                -and
        $_ -notmatch 'Deployment Image Servicing'       -and
        $_ -notmatch '^Version:'                        -and
        $_ -notmatch '^Image Version:'                  -and
        $_ -notmatch 'Beginning system scan'            -and
        $_ -notmatch 'Beginning verification phase'     -and
        $_ -notmatch 'This process will take some time' -and
        $_ -notmatch 'Do not close this Command Prompt'
    }
}

$results = @()

# --- DISM CheckHealth (quick flag check) ---
Write-Output "Running DISM CheckHealth..."
$checkLines = Get-CleanOutput { DISM.exe /Online /Cleanup-Image /CheckHealth }
$checkExit  = $LASTEXITCODE
$checkText  = $checkLines -join ' '

switch -Regex ($checkText) {
    'not repairable'                         { $results += "CheckHealth: Corruption NOT repairable."       ; break }
    'component store is repairable'          { $results += "CheckHealth: Corruption flagged (repairable)." ; break }
    'No component store corruption detected' { $results += "CheckHealth: No corruption flagged."           ; break }
    default                                  { $results += "CheckHealth: Exit code $checkExit." }
}

# --- DISM ScanHealth (full scan) ---
Write-Output "Running DISM ScanHealth..."
$scanLines = Get-CleanOutput { DISM.exe /Online /Cleanup-Image /ScanHealth }
$scanExit  = $LASTEXITCODE
$scanText  = $scanLines -join ' '

switch -Regex ($scanText) {
    'not repairable'                         { $results += "ScanHealth: Corruption NOT repairable."   ; break }
    'component store is repairable'          { $results += "ScanHealth: Repairable corruption found." ; break }
    'No component store corruption detected' { $results += "ScanHealth: No corruption detected."      ; break }
    default                                  { $results += "ScanHealth: Exit code $scanExit." }
}

# --- DISM RestoreHealth (repair) ---
Write-Output "Running DISM RestoreHealth..."
$dismLines = Get-CleanOutput { DISM.exe /Online /Cleanup-Image /RestoreHealth /NoRestart }
$dismExit  = $LASTEXITCODE
$dismText  = $dismLines -join ' '

switch -Regex ($dismText) {
    'The restore operation completed successfully' { $results += "RestoreHealth: Restore completed successfully." ; break }
    'The source files could not be found'          { $results += "RestoreHealth: FAILED - source files not found." ; break }
    default {
        if ($dismExit -eq 0) { $results += "RestoreHealth: Completed (exit 0)." }
        else                 { $results += "RestoreHealth: Exit code $dismExit - see C:\Windows\Logs\DISM\dism.log." }
    }
}

# --- SFC ---
Write-Output "Running SFC /scannow..."
$sfcLines = Get-CleanOutput { sfc.exe /scannow }
$sfcExit  = $LASTEXITCODE
$sfcText  = $sfcLines -join ' '

switch -Regex ($sfcText) {
    'did not find any integrity violations'                  { $results += "SFC: No integrity violations."               ; break }
    'found corrupt files and successfully repaired them'     { $results += "SFC: Corruption found and repaired."         ; break }
    'found corrupt files but was unable to fix some of them' { $results += "SFC: Corruption found - NOT fully repaired." ; break }
    'could not perform the requested operation'              { $results += "SFC: Could not run - try Safe Mode."         ; break }
    default {
        if ($sfcExit -eq 0) { $results += "SFC: Completed (exit 0)." }
        else                { $results += "SFC: Exit code $sfcExit - see C:\Windows\Logs\CBS\CBS.log." }
    }
}

# --- Status flags ---
$corruptionFound = ($checkText -match 'component store is repairable') -or
                   ($scanText  -match 'component store is repairable') -or
                   ($sfcText   -match 'found corrupt files')

$repairFailed    = ($checkText -match 'not repairable') -or
                   ($scanText  -match 'not repairable') -or
                   ($dismText  -match 'source files could not be found') -or
                   ($sfcText   -match 'unable to fix some of them')

$reboot = (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') -or
          (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')

$status = @()
if     ($repairFailed)    { $status += "❌ Repair Incomplete" }
elseif ($corruptionFound) { $status += "⚠️ Corruption Found - Repaired" }
else                      { $status += "✅ No Corruption Detected" }

if ($reboot) { $status += "⚠️ Reboot Required" } else { $status += "✅ No Reboot Required" }

$body = @"
$($status -join " | ")

Computer: $env:COMPUTERNAME
Time:     $(Get-Date -Format 'yyyy-MM-dd HH:mm')

$($results -join "`n")
"@

if ($body.Length -gt 3900) { $body = $body.Substring(0, 3900) }

$priority = if ($repairFailed) { "high" } elseif ($corruptionFound -or $reboot) { "default" } else { "low" }

try {
    Invoke-RestMethod -Uri "$NtfyServer/$NtfyTopic" -Method Post `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) `
        -Headers @{ Title = "DISM/SFC - $env:COMPUTERNAME"; Priority = $priority } `
        -TimeoutSec 30 | Out-Null
}
catch {
    Write-Output "ntfy post failed: $($_.Exception.Message)"
}

Write-Output ""
Write-Output $body

}
