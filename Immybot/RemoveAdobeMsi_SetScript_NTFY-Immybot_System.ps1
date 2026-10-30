<#
.SYNOPSIS
    Moves duplicate Adobe Reader MSI files from C:\Windows\Installer to a backup folder,
    then removes all temporary files from system temp folders.
.DESCRIPTION
    Identifies all Adobe Reader MSI files in the Windows Installer cache, keeps the largest
    (most recent/complete) one in place, and moves the rest to C:\Temp\AdobeBackup.
    Then cleans up temporary files from C:\Temp and C:\Windows\Temp.
    Sends a summary notification via ntfy.
    Requires administrator privileges to execute successfully.
#>

# --- ntfy Settings ---
$ntfyServer = "https://ntfy.sh"           # change to your self-hosted URL if needed
$ntfyTopic  = "Insertyourtopicnamehere"     # change to your topic

$InstallerPath = "C:\Windows\Installer"
$BackupPath    = "C:\Temp\AdobeBackup"
$LogPath       = "C:\Temp\AdobeCleanup_$(Get-Date -Format 'yyyy-MM-dd_HHmm').log"

# --- Define Absolute Paths ---
$CustomTemp = "C:\Temp"
$WinTemp    = "C:\Windows\Temp"

$FreeStart = (Get-PSDrive C).Free
$Moved     = 0
$Failed    = 0
$MovedGB   = 0
$KeepName  = "None"

# ============================================================
# PART 1 - Adobe Reader MSI Cleanup
# ============================================================

# Create backup folder if needed
if (-not (Test-Path $BackupPath)) { New-Item -Path $BackupPath -ItemType Directory | Out-Null }

Write-Host "Scanning for Adobe Reader MSI files..." -ForegroundColor Cyan

$Installer = New-Object -ComObject WindowsInstaller.Installer

$AdobeMSIs = Get-ChildItem -Path $InstallerPath -Filter *.msi | Where-Object {
    try {
        $DB   = $Installer.OpenDatabase($_.FullName, 0)
        $View = $DB.OpenView("SELECT Value FROM Property WHERE Property='ProductName'")
        $View.Execute()
        $Record = $View.Fetch()
        $Name = if ($Record) { $Record.StringData(1) } else { "" }
        $Name -like "*Adobe Reader*"
    } catch { $false }
}

Write-Host "Found $($AdobeMSIs.Count) Adobe Reader MSI files." -ForegroundColor Yellow

if ($AdobeMSIs.Count -eq 0) {
    Write-Host "Nothing to do." -ForegroundColor Green
}
else {
    # Keep the largest file (most complete/recent installer), move the rest
    $Keep = $AdobeMSIs | Sort-Object Length -Descending | Select-Object -First 1
    $KeepName = "$($Keep.Name) ($([math]::Round($Keep.Length / 1MB, 2)) MB)"
    Write-Host "Keeping: $KeepName" -ForegroundColor Green

    $ToMove  = $AdobeMSIs | Where-Object { $_.FullName -ne $Keep.FullName }
    $MovedGB = [math]::Round(($ToMove | Measure-Object -Property Length -Sum).Sum / 1GB, 2)

    Write-Host "Moving $($ToMove.Count) files (~$MovedGB GB) to $BackupPath..." -ForegroundColor Cyan

    $Log = [System.Collections.Generic.List[string]]::new()
    $Log.Add("Adobe MSI Cleanup Log - $(Get-Date)")
    $Log.Add("Kept: $($Keep.FullName)")
    $Log.Add("---")

    foreach ($File in $ToMove) {
        try {
            Move-Item -Path $File.FullName -Destination $BackupPath -Force
            $Log.Add("MOVED: $($File.Name)")
            $Moved++
        } catch {
            Write-Host "  Failed to move $($File.Name): $_" -ForegroundColor Red
            $Log.Add("FAILED: $($File.Name) - $_")
            $Failed++
        }
    }

    $Log | Out-File -FilePath $LogPath -Encoding UTF8
}

# ============================================================
# PART 2 - Temp Folder Cleanup
# ============================================================

# --- Clean C:\Temp ---
if (Test-Path $CustomTemp) {
    Write-Host "Cleaning $CustomTemp..."
    Get-ChildItem -Path $CustomTemp -Recurse -ErrorAction SilentlyContinue | 
    Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
}

# --- Clean C:\Windows\Temp ---
if (Test-Path $WinTemp) {
    Write-Host "Cleaning $WinTemp..."
    Get-ChildItem -Path $WinTemp -Recurse -ErrorAction SilentlyContinue | 
    Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
}

Write-Host "Cleanup process complete."

# ============================================================
# PART 3 - ntfy Notification
# ============================================================
$FreeEnd = (Get-PSDrive C).Free
$FreedGB = [math]::Round(($FreeEnd - $FreeStart) / 1GB, 2)
$FreeNow = [math]::Round($FreeEnd / 1GB, 2)

$Message = @"
Device: $env:COMPUTERNAME
Adobe MSIs found: $($AdobeMSIs.Count)
Kept: $KeepName
Moved then cleared: $Moved (~$MovedGB GB)
Failed: $Failed
Temp cleaned: C:\Temp, C:\Windows\Temp
Total space freed: $FreedGB GB
C: free now: $FreeNow GB
"@

if ($Failed -gt 0) {
    $Title    = "Cleanup finished with errors - $env:COMPUTERNAME"
    $Tags     = "warning"
    $Priority = "high"
} else {
    $Title    = "Cleanup complete - $env:COMPUTERNAME"
    $Tags     = "white_check_mark,broom"
    $Priority = "default"
}

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-RestMethod -Uri "$ntfyServer/$ntfyTopic" -Method Post -Body $Message -Headers @{
        Title    = $Title
        Tags     = $Tags
        Priority = $Priority
    } | Out-Null
    Write-Host "ntfy notification sent." -ForegroundColor Green
} catch {
    Write-Host "ntfy notification failed: $_" -ForegroundColor Red
}

Write-Host "`n--- DONE ---" -ForegroundColor Yellow
Write-Host $Message