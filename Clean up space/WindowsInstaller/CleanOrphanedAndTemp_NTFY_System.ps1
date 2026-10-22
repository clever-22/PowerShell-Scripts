#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Cleans orphaned MSP files from Windows Installer folder and purges temp directories.
.DESCRIPTION
    1. Scans C:\Windows\Installer for orphaned MSP patch files with NO metadata.
       Moves them directly to a quarantine folder (no zip, no prompts).
    2. Cleans C:\Temp and C:\Windows\Temp.
    Sends an ntfy.sh notification when complete.
#>

# CONFIGURATION - CHANGE THIS!!!
$ntfyTopic = "Insertyourtopicnamehere"
$ntfyServer = "https://ntfy.sh"

$Installer      = New-Object -ComObject WindowsInstaller.Installer
$InstallerPath  = "C:\Windows\Installer"
$QuarantinePath = "C:\Temp\Installer_Orphaned_$(Get-Date -Format yyyyMMdd_HHmmss)"
$Results        = New-Object System.Collections.Generic.List[PSCustomObject]
$EnableNtfy     = $true
$StartTime      = Get-Date
$MovedCount     = 0
$FailedCount    = 0
$OrphanedSizeGB = 0
$OrphanedSizeMB = 0

Write-Host "Scanning $InstallerPath... This may take a minute!" -ForegroundColor Cyan

Get-ChildItem -Path $InstallerPath -Filter *.msp -ErrorAction SilentlyContinue | ForEach-Object {
    $File         = $_
    $Status       = "IN USE"
    $Identity     = ""
    $IsOrphaned   = $true
    $OrphanReason = ""
    $HasMetadata  = $false

    try {
        $SummaryInfo = $Installer.SummaryInformation($File.FullName, 0)

        $Identity = $SummaryInfo.Property(3)
        if ([string]::IsNullOrWhiteSpace($Identity)) { $Identity = $SummaryInfo.Property(2) }
        if ([string]::IsNullOrWhiteSpace($Identity)) { $Identity = $SummaryInfo.Property(4) }

        if (-not [string]::IsNullOrWhiteSpace($Identity)) { $HasMetadata = $true }

        $PatchCode = $SummaryInfo.Property(9)

        if ($PatchCode) {
            try {
                $PatchInfo = $Installer.PatchesEx($PatchCode, "", 0)
                if ($PatchInfo.Count -gt 0) {
                    $IsOrphaned   = $false
                    $Status       = "IN USE"
                    $OrphanReason = ""
                } else {
                    $IsOrphaned   = $true
                    $OrphanReason = "Product uninstalled"
                }
            } catch {
                $IsOrphaned   = $true
                $OrphanReason = "Not registered"
            }
        } else {
            $IsOrphaned   = $true
            $OrphanReason = "No PatchCode"
        }

        if ($IsOrphaned) {
            if ([string]::IsNullOrWhiteSpace($Identity)) {
                $Identity     = "Unknown (No Metadata)"
                $Status       = "ORPHANED - NO METADATA"
                if ([string]::IsNullOrWhiteSpace($OrphanReason)) { $OrphanReason = "No metadata" }
            } else {
                $Status = "ORPHANED - HAS METADATA"
            }
        } else {
            $Status = "IN USE"
        }

    } catch {
        $Identity     = "Unreadable File"
        $Status       = "ORPHANED - NO METADATA"
        $IsOrphaned   = $true
        $OrphanReason = "Corrupted"
        $HasMetadata  = $false
    }

    $LastModified = $File.LastWriteTime
    $AgeDays      = (New-TimeSpan -Start $LastModified -End (Get-Date)).Days

    $Results.Add([PSCustomObject]@{
        FileName     = $File.Name
        Status       = $Status
        SizeMB       = [math]::Round($File.Length / 1MB, 2)
        AgeDays      = $AgeDays
        LastModified = $LastModified
        Date         = $LastModified.Date
        Identity     = $Identity
        OrphanReason = $OrphanReason
        HasMetadata  = $HasMetadata
        IsOrphaned   = $IsOrphaned
        FullPath     = $File.FullName
    })
}

Write-Host "`n--- ALL INSTALLER PACKAGES (Sorted by Date) ---" -ForegroundColor Cyan
$Results | Sort-Object Date, SizeMB -Descending |
    Format-Table FileName, Status, SizeMB, AgeDays, Date, Identity -AutoSize

Write-Host "`n--- PACKAGE COUNT BY DATE ---" -ForegroundColor Cyan
$Results | Group-Object Date | Sort-Object Name |
    Select-Object @{Name="Date";Expression={$_.Name}},
                  @{Name="PackageCount";Expression={$_.Count}},
                  @{Name="TotalSizeGB";Expression={[math]::Round((($_.Group | Measure-Object SizeMB -Sum).Sum) / 1024, 2)}} |
    Format-Table -AutoSize

$AllOrphaned = $Results | Where-Object { $_.IsOrphaned -eq $true }

if ($AllOrphaned.Count -gt 0) {
    Write-Host "`n=== ALL ORPHANED FILES ===" -ForegroundColor Cyan
    $AllOrphaned | Sort-Object Date, SizeMB -Descending |
        Format-Table FileName, SizeMB, AgeDays,
            @{Label="Date";Expression={$_.Date.ToString("yyyy-MM-dd")}},
            OrphanReason, Identity -AutoSize
    $AllOrphanedSizeGB = ($AllOrphaned | Measure-Object SizeMB -Sum).Sum / 1024
    Write-Host "Total orphaned: $($AllOrphaned.Count) ($([math]::Round($AllOrphanedSizeGB, 2)) GB)" -ForegroundColor Yellow
}

$OrphanedWithMetadata = $Results | Where-Object { $_.Status -eq "ORPHANED - HAS METADATA" }

if ($OrphanedWithMetadata.Count -gt 0) {
    Write-Host "`n=== ORPHANED WITH METADATA (PRESERVED) ===" -ForegroundColor Green
    $OrphanedWithMetadata | Sort-Object Date, SizeMB -Descending |
        Format-Table FileName, SizeMB, AgeDays,
            @{Label="Date";Expression={$_.Date.ToString("yyyy-MM-dd")}},
            Identity -AutoSize
    $MetadataSizeGB = ($OrphanedWithMetadata | Measure-Object SizeMB -Sum).Sum / 1024
    Write-Host "Total preserved: $($OrphanedWithMetadata.Count) files, $([math]::Round($MetadataSizeGB, 2)) GB" -ForegroundColor Green
}

$OrphanedNoMetadata = $Results | Where-Object { $_.Status -eq "ORPHANED - NO METADATA" }
$TotalSizeGB        = ($Results | Measure-Object -Property SizeMB -Sum).Sum / 1024

if ($OrphanedNoMetadata.Count -eq 0) {
    Write-Host "`nNo orphaned MSP files without metadata found." -ForegroundColor Green
} else {
    $OrphanedSizeMB = ($OrphanedNoMetadata | Measure-Object SizeMB -Sum).Sum
    $OrphanedSizeGB = $OrphanedSizeMB / 1024

    Write-Host "`n=== ORPHANED - NO METADATA (WILL BE QUARANTINED) ===" -ForegroundColor Red
    Write-Host "Total: $($OrphanedNoMetadata.Count) files, $([math]::Round($OrphanedSizeGB, 2)) GB" -ForegroundColor Cyan

    $OrphanedNoMetadata | Sort-Object Date, SizeMB -Descending |
        Format-Table FileName, SizeMB, AgeDays,
            @{Label="Date";Expression={$_.Date.ToString("yyyy-MM-dd")}},
            OrphanReason, Identity -AutoSize

    Write-Host "`n--- SUMMARY ---" -ForegroundColor Yellow
    Write-Host "Total Installer Folder Size: $([math]::Round($TotalSizeGB, 2)) GB"
    Write-Host "All Orphaned: $($AllOrphaned.Count) ($([math]::Round(($AllOrphaned | Measure-Object SizeMB -Sum).Sum / 1024, 2)) GB)" -ForegroundColor Cyan
    Write-Host "  With Metadata (Preserved): $($OrphanedWithMetadata.Count)" -ForegroundColor Green
    Write-Host "  Without Metadata (Quarantining): $($OrphanedNoMetadata.Count) ($([math]::Round($OrphanedSizeGB, 2)) GB)" -ForegroundColor Red

    Write-Host "`nCreating quarantine directory: $QuarantinePath" -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $QuarantinePath -Force | Out-Null

    Write-Host "Moving $($OrphanedNoMetadata.Count) files..." -ForegroundColor Yellow

    foreach ($File in $OrphanedNoMetadata) {
        try {
            Move-Item -Path $File.FullPath -Destination $QuarantinePath -Force
            $MovedCount++
        } catch {
            Write-Host "Failed to move $($File.FileName): $_" -ForegroundColor Red
            $FailedCount++
        }
    }

    Write-Host "Done. Moved: $MovedCount  |  Failed: $FailedCount" -ForegroundColor Green
    Write-Host "Quarantine location: $QuarantinePath" -ForegroundColor Gray
}

# ============================================================
# PART 2 - TEMP FOLDER CLEANUP
# ============================================================

$TempFolders    = @("C:\Temp", "C:\Windows\Temp")
$TempBytesFreed = 0

Write-Host "`n--- TEMP FOLDER CLEANUP ---" -ForegroundColor Cyan

foreach ($TempPath in $TempFolders) {
    if (Test-Path $TempPath) {
        $SizeBefore = (Get-ChildItem -Path $TempPath -Recurse -ErrorAction SilentlyContinue |
                       Measure-Object -Property Length -Sum).Sum
        Write-Host "Cleaning $TempPath ($([math]::Round($SizeBefore / 1MB, 2)) MB)..." -ForegroundColor Yellow
        Get-ChildItem -Path $TempPath -Recurse -ErrorAction SilentlyContinue |
            Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        $TempBytesFreed += $SizeBefore
        Write-Host "  Done." -ForegroundColor Green
    } else {
        Write-Host "$TempPath not found, skipping." -ForegroundColor Gray
    }
}

$TempGBFreed = [math]::Round($TempBytesFreed / 1GB, 2)
Write-Host "Temp cleanup complete. Freed ~$TempGBFreed GB." -ForegroundColor Green

# ============================================================
# FINAL SUMMARY + NTFY
# ============================================================

$Duration = New-TimeSpan -Start $StartTime -End (Get-Date)

Write-Host "`n--- FINAL SUMMARY ---" -ForegroundColor Green
Write-Host "MSP orphans quarantined : $MovedCount"
Write-Host "MSP files preserved     : $($OrphanedWithMetadata.Count)"
Write-Host "MSP space recovered     : $([math]::Round($OrphanedSizeGB, 2)) GB"
Write-Host "Temp space freed        : ~$TempGBFreed GB"
Write-Host "Runtime                 : $($Duration.ToString())"
Write-Host "`nIMPORTANT: Test your system before permanently deleting quarantined files!" -ForegroundColor Yellow

if ($EnableNtfy) {
    $Message = "Cleanup completed on $env:COMPUTERNAME`nMSP Orphans Quarantined: $MovedCount`nMSP Space Recovered: $([math]::Round($OrphanedSizeGB, 2)) GB`nTemp Space Freed: ~$TempGBFreed GB`nRuntime: $($Duration.ToString())"
    curl.exe -H "Title: System Cleanup Complete" -H "Tags: white_check_mark,recycle" -H "Priority: 3" -d $Message "$ntfyServer/$ntfyTopic"
}