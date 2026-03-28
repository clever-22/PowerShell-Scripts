<#
.SYNOPSIS
    Moves duplicate Adobe Reader MSI files from C:\Windows\Installer to a backup folder.
.DESCRIPTION
    Identifies all Adobe Reader MSI files in the Windows Installer cache, keeps the largest
    (most recent/complete) one in place, and moves the rest to C:\Temp\AdobeBackup.
    Review the backup folder after testing, then delete manually when satisfied.
#>

$InstallerPath = "C:\Windows\Installer"
$BackupPath    = "C:\Temp\AdobeBackup"
$LogPath       = "C:\Temp\AdobeCleanup_$(Get-Date -Format 'yyyy-MM-dd_HHmm').log"

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
    exit
}

# Keep the largest file (most complete/recent installer), move the rest
$Keep = $AdobeMSIs | Sort-Object Length -Descending | Select-Object -First 1
Write-Host "Keeping: $($Keep.Name) ($([math]::Round($Keep.Length / 1MB, 2)) MB)" -ForegroundColor Green

$ToMove   = $AdobeMSIs | Where-Object { $_.FullName -ne $Keep.FullName }
$MovedGB  = [math]::Round(($ToMove | Measure-Object -Property Length -Sum).Sum / 1GB, 2)

Write-Host "Moving $($ToMove.Count) files (~$MovedGB GB) to $BackupPath..." -ForegroundColor Cyan

$Log = [System.Collections.Generic.List[string]]::new()
$Log.Add("Adobe MSI Cleanup Log - $(Get-Date)")
$Log.Add("Kept: $($Keep.FullName)")
$Log.Add("---")

foreach ($File in $ToMove) {
    try {
        Move-Item -Path $File.FullName -Destination $BackupPath -Force
        $Log.Add("MOVED: $($File.Name)")
    } catch {
        Write-Host "  Failed to move $($File.Name): $_" -ForegroundColor Red
        $Log.Add("FAILED: $($File.Name) - $_")
    }
}

$Log | Out-File -FilePath $LogPath -Encoding UTF8

Write-Host "`n--- DONE ---" -ForegroundColor Yellow
Write-Host "Files moved to: $BackupPath"
Write-Host "Log saved to:   $LogPath"
Write-Host ""
Write-Host "Test Adobe Reader still works, then delete $BackupPath to free the space." -ForegroundColor Cyan