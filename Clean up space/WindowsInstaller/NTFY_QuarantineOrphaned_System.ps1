<#
.SYNOPSIS
    Identifies and quarantines orphaned MSP files from Windows Installer folder
.DESCRIPTION
    Scans C:\Windows\Installer for orphaned MSP patch files with no metadata.
    Requires manual confirmation, moves them to a quarantine folder, zips the archive,
    and sends ntfy.sh notification when complete. After
#>

# CONFIGURATION - CHANGE THIS!!!
$ntfyTopic = "Insertyourtopicnamehere"
$ntfyServer = "https://ntfy.sh"

# -------------------------------
# Windows Installer MSP Cleanup Tool
# + Metadata extraction (Identity/Product)
# + AgeDays calculation
# + Sort by Date
# + Count Packages by Date
# + Manual confirmation required
# + Zips quarantine folder
# + Completion ntfy notification
# + ONLY removes files with NO metadata
# -------------------------------

$Installer = New-Object -ComObject WindowsInstaller.Installer
$InstallerPath = "C:\Windows\Installer"
$QuarantinePath = "C:\Temp\Installer_Orphaned_$(Get-Date -Format yyyyMMdd_HHmmss)"
$ZipPath = "$QuarantinePath.zip"
$Results = New-Object System.Collections.Generic.List[PSCustomObject]
$EnableNtfy = $true
$StartTime = Get-Date

Write-Host "Scanning $InstallerPath... This may take a minute given the size!" -ForegroundColor Cyan

Get-ChildItem -Path $InstallerPath -Filter *.msp -ErrorAction SilentlyContinue | ForEach-Object {
    $File = $_
    $Status = "IN USE"
    $Identity = ""
    $IsOrphaned = $true
    $OrphanReason = ""
    $HasMetadata = $false
    
    try {
        $SummaryInfo = $Installer.SummaryInformation($File.FullName, 0)
        
        # Extract Identity/Product Name
        $Identity = $SummaryInfo.Property(3)  # Subject
        if ([string]::IsNullOrWhiteSpace($Identity)) { $Identity = $SummaryInfo.Property(2) }  # Title
        if ([string]::IsNullOrWhiteSpace($Identity)) { $Identity = $SummaryInfo.Property(4) }  # Author
        
        # Check if we have valid metadata
        if (-not [string]::IsNullOrWhiteSpace($Identity)) {
            $HasMetadata = $true
        }
        
        # Check if orphaned by attempting to validate PatchCode
        $PatchCode = $SummaryInfo.Property(9)
        
        if ($PatchCode) {
            try {
                $PatchInfo = $Installer.PatchesEx($PatchCode, "", 0)
                
                if ($PatchInfo.Count -gt 0) {
                    $IsOrphaned = $false
                    $Status = "IN USE"
                    $OrphanReason = ""
                } else {
                    $IsOrphaned = $true
                    $OrphanReason = "Product uninstalled"
                }
            } catch {
                $IsOrphaned = $true
                $OrphanReason = "Not registered"
            }
        } else {
            $IsOrphaned = $true
            $OrphanReason = "No PatchCode"
        }
        
        # Set status based on orphaned state AND metadata
        if ($IsOrphaned) {
            if ([string]::IsNullOrWhiteSpace($Identity)) {
                $Identity = "Unknown (No Metadata)"
                $Status = "ORPHANED - NO METADATA"
                if ([string]::IsNullOrWhiteSpace($OrphanReason)) {
                    $OrphanReason = "No metadata"
                }
            } else {
                # Orphaned but HAS metadata - won't be deleted
                $Status = "ORPHANED - HAS METADATA"
            }
        } else {
            $Status = "IN USE"
        }
        
    } catch {
        $Identity = "Unreadable File"
        $Status = "ORPHANED - NO METADATA"
        $IsOrphaned = $true
        $OrphanReason = "Corrupted"
        $HasMetadata = $false
    }
    
    $LastModified = $File.LastWriteTime
    $AgeDays = (New-TimeSpan -Start $LastModified -End (Get-Date)).Days
    
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

# ---- MAIN TABLE (SORTED BY DATE) ----
Write-Host "`n--- ALL INSTALLER PACKAGES (Sorted by Date) ---" -ForegroundColor Cyan
$Results |
    Sort-Object Date, SizeMB -Descending |
    Format-Table FileName, Status, SizeMB, AgeDays, Date, Identity -AutoSize

# ---- COUNT PACKAGES BY DATE ----
Write-Host "`n--- PACKAGE COUNT BY DATE ---" -ForegroundColor Cyan
$ByDate = $Results |
    Group-Object Date |
    Sort-Object Name

$ByDate |
    Select-Object @{Name="Date";Expression={$_.Name}},
                  @{Name="PackageCount";Expression={$_.Count}},
                  @{Name="TotalSizeGB";Expression={
                      [math]::Round(
                          (($_.Group | Measure-Object SizeMB -Sum).Sum) / 1024, 2)
                  }} |
    Format-Table -AutoSize

# ---- ALL ORPHANED FILES (FOR INFORMATION) ----
$AllOrphaned = $Results | Where-Object { $_.IsOrphaned -eq $true }

if ($AllOrphaned.Count -gt 0) {
    Write-Host "`n=== ALL ORPHANED FILES (NOT REGISTERED IN WINDOWS INSTALLER) ===" -ForegroundColor Cyan
    $AllOrphaned |
        Sort-Object Date, SizeMB -Descending |
        Format-Table @{Label="FileName";Expression={$_.FileName};Width=15},
                     @{Label="SizeMB";Expression={$_.SizeMB};Width=8},
                     @{Label="Age";Expression={$_.AgeDays};Width=6},
                     @{Label="Date";Expression={$_.Date.ToString("yyyy-MM-dd")};Width=12},
                     @{Label="Reason";Expression={$_.OrphanReason};Width=18},
                     @{Label="Identity";Expression={$_.Identity}} -Wrap
    
    $AllOrphanedSizeGB = ($AllOrphaned | Measure-Object SizeMB -Sum).Sum / 1024
    Write-Host "Total orphaned files: $($AllOrphaned.Count) ($([math]::Round($AllOrphanedSizeGB, 2)) GB)" -ForegroundColor Yellow
}

# ---- FILES WITH METADATA (NOT FOR DELETION) ----
$OrphanedWithMetadata = $Results | Where-Object { $_.Status -eq "ORPHANED - HAS METADATA" }

if ($OrphanedWithMetadata.Count -gt 0) {
    Write-Host "`n=== ORPHANED FILES WITH METADATA (WILL BE PRESERVED) ===" -ForegroundColor Green
    Write-Host "These files are orphaned but have product names - NOT deleting:" -ForegroundColor Yellow
    $OrphanedWithMetadata |
        Sort-Object Date, SizeMB -Descending |
        Format-Table @{Label="FileName";Expression={$_.FileName};Width=15},
                     @{Label="SizeMB";Expression={$_.SizeMB};Width=8},
                     @{Label="Age";Expression={$_.AgeDays};Width=6},
                     @{Label="Date";Expression={$_.Date.ToString("yyyy-MM-dd")};Width=12},
                     @{Label="Identity";Expression={$_.Identity}} -Wrap
    
    $MetadataSizeGB = ($OrphanedWithMetadata | Measure-Object SizeMB -Sum).Sum / 1024
    Write-Host "Total: $($OrphanedWithMetadata.Count) files, $([math]::Round($MetadataSizeGB, 2)) GB (PRESERVED)" -ForegroundColor Green
}

# ---- ORPHANED FILES WITHOUT METADATA (WILL BE DELETED) ----
$OrphanedNoMetadata = $Results | Where-Object { $_.Status -eq "ORPHANED - NO METADATA" }

if ($OrphanedNoMetadata.Count -eq 0) {
    Write-Host "`nNo orphaned MSP files without metadata found!" -ForegroundColor Green
    
    # Send ntfy notification for completion
    if ($EnableNtfy) {
        $Duration = New-TimeSpan -Start $StartTime -End (Get-Date)
        $Message = @"
Installer MSP scan completed on $env:COMPUTERNAME
Total orphaned files: $($AllOrphaned.Count)
Orphaned with metadata (preserved): $($OrphanedWithMetadata.Count)
Orphaned without metadata (for deletion): 0
Runtime: $($Duration.ToString())
"@
        curl.exe `
            -H "Title: Installer Scan Complete" `
            -H "Tags: calendar,package,white_check_mark" `
            -H "Priority: 3" `
            -d $Message `
            $ntfyServer/$ntfyTopic
    }
    exit
}

Write-Host "`n=== ORPHANED FILES WITHOUT METADATA (WILL BE DELETED) ===" -ForegroundColor Red
Write-Host "Total orphaned files (no product name): $($OrphanedNoMetadata.Count)" -ForegroundColor Cyan
$OrphanedSizeMB = ($OrphanedNoMetadata | Measure-Object SizeMB -Sum).Sum
Write-Host "Total size: $([math]::Round($OrphanedSizeMB / 1024, 2)) GB ($([math]::Round($OrphanedSizeMB, 2)) MB)" -ForegroundColor Cyan
Write-Host ""

# Display detailed orphaned files table
Write-Host "Detailed file list:" -ForegroundColor White
$OrphanedNoMetadata |
    Sort-Object Date, SizeMB -Descending |
    Format-Table @{Label="FileName";Expression={$_.FileName};Width=15},
                 @{Label="SizeMB";Expression={$_.SizeMB};Width=8},
                 @{Label="Age";Expression={$_.AgeDays};Width=6},
                 @{Label="Date";Expression={$_.Date.ToString("yyyy-MM-dd")};Width=12},
                 @{Label="Reason";Expression={$_.OrphanReason};Width=18},
                 @{Label="Identity";Expression={$_.Identity}} -Wrap

# ---- SUMMARY ----
$TotalSizeGB = ($Results | Measure-Object -Property SizeMB -Sum).Sum / 1024
$OrphanedSizeGB = $OrphanedSizeMB / 1024

Write-Host "`n--- SUMMARY ---" -ForegroundColor Yellow
Write-Host "Total Installer Folder Size: $([math]::Round($TotalSizeGB, 2)) GB"
Write-Host "All Orphaned Files: $($AllOrphaned.Count) ($([math]::Round(($AllOrphaned | Measure-Object SizeMB -Sum).Sum / 1024, 2)) GB)" -ForegroundColor Cyan
Write-Host "  ├─ With Metadata (Preserved): $($OrphanedWithMetadata.Count) ($([math]::Round(($OrphanedWithMetadata | Measure-Object SizeMB -Sum).Sum / 1024, 2)) GB)" -ForegroundColor Green
Write-Host "  └─ Without Metadata (Will Delete): $($OrphanedNoMetadata.Count) ($([math]::Round($OrphanedSizeGB, 2)) GB)" -ForegroundColor Red

# ---- CONFIRMATION PROMPT ----
Write-Host "`nQuarantine location: $QuarantinePath" -ForegroundColor Gray
Write-Host "Zip file location: $ZipPath" -ForegroundColor Gray
Write-Host "Do you want to move orphaned files WITHOUT metadata to quarantine?" -ForegroundColor Yellow
Write-Host "Type 'yes' to proceed or anything else to cancel: " -ForegroundColor Yellow -NoNewline
$Confirmation = Read-Host

if ($Confirmation.ToLower() -ne "yes") {
    Write-Host "`nOperation cancelled. No files were moved." -ForegroundColor Red
    
    # Send ntfy notification for cancellation
    if ($EnableNtfy) {
        $Duration = New-TimeSpan -Start $StartTime -End (Get-Date)
        $Message = @"
Installer MSP scan completed on $env:COMPUTERNAME
Total Installer Size: $([math]::Round($TotalSizeGB, 2)) GB
All Orphaned: $($AllOrphaned.Count) ($([math]::Round(($AllOrphaned | Measure-Object SizeMB -Sum).Sum / 1024, 2)) GB)
With Metadata: $($OrphanedWithMetadata.Count)
Without Metadata: $($OrphanedNoMetadata.Count)
USER CANCELLED CLEANUP
Runtime: $($Duration.ToString())
"@
        curl.exe `
            -H "Title: Installer Scan Complete (Cancelled)" `
            -H "Tags: calendar,package,warning" `
            -H "Priority: 3" `
            -d $Message `
            https://ntfy.sh/$NtfyTopic
    }
    exit
}

# ---- MOVE ORPHANED FILES ----
Write-Host "`nCreating quarantine directory..." -ForegroundColor Cyan
New-Item -ItemType Directory -Path $QuarantinePath -Force | Out-Null

Write-Host "Moving $($OrphanedNoMetadata.Count) orphaned MSP files to quarantine..." -ForegroundColor Yellow
$MovedCount = 0
$FailedCount = 0

foreach ($File in $OrphanedNoMetadata) {
    try {
        Move-Item -Path $File.FullPath -Destination $QuarantinePath -Force
        $MovedCount++
    } catch {
        Write-Host "Failed to move $($File.FileName): $_" -ForegroundColor Red
        $FailedCount++
    }
}

# ---- ZIP QUARANTINE FOLDER ----
if ($MovedCount -gt 0) {
    Write-Host "`nCreating ZIP archive of quarantine folder..." -ForegroundColor Cyan
    try {
        Compress-Archive -Path "$QuarantinePath\*" -DestinationPath $ZipPath -CompressionLevel Optimal -Force
        $ZipSizeMB = [math]::Round((Get-Item $ZipPath).Length / 1MB, 2)
        $CompressionRatio = [math]::Round(($ZipSizeMB / $OrphanedSizeMB) * 100, 1)
        
        Write-Host "ZIP archive created successfully!" -ForegroundColor Green
        Write-Host "Original size: $([math]::Round($OrphanedSizeMB, 2)) MB" -ForegroundColor White
        Write-Host "Compressed size: $ZipSizeMB MB ($CompressionRatio% of original)" -ForegroundColor White
        Write-Host "ZIP location: $ZipPath" -ForegroundColor White
        
        # Optionally delete the uncompressed quarantine folder to save space
        Write-Host "`nDo you want to delete the uncompressed quarantine folder to save space?" -ForegroundColor Yellow
        Write-Host "The files are safely stored in the ZIP. Type 'yes' to delete folder: " -ForegroundColor Yellow -NoNewline
        $DeleteFolder = Read-Host
        
        if ($DeleteFolder.ToLower() -eq "yes") {
            Remove-Item -Path $QuarantinePath -Recurse -Force
            Write-Host "Uncompressed quarantine folder deleted. ZIP archive preserved." -ForegroundColor Green
        } else {
            Write-Host "Uncompressed quarantine folder preserved at: $QuarantinePath" -ForegroundColor Cyan
        }
        
    } catch {
        Write-Host "Failed to create ZIP archive: $_" -ForegroundColor Red
        Write-Host "Quarantine folder preserved at: $QuarantinePath" -ForegroundColor Yellow
        $ZipSizeMB = 0
    }
} else {
    Write-Host "`nNo files were moved, skipping ZIP creation." -ForegroundColor Yellow
}

# ---- FINAL SUMMARY ----
$Duration = New-TimeSpan -Start $StartTime -End (Get-Date)

Write-Host "`n--- CLEANUP SUMMARY ---" -ForegroundColor Green
Write-Host "Orphaned MSP files moved: $MovedCount of $($OrphanedNoMetadata.Count)"
Write-Host "Failed moves: $FailedCount"
Write-Host "Recovered disk space: $([math]::Round($OrphanedSizeGB, 2)) GB"
if ($MovedCount -gt 0 -and $ZipSizeMB -gt 0) {
    Write-Host "ZIP archive size: $ZipSizeMB MB" -ForegroundColor Cyan
    Write-Host "ZIP location: $ZipPath" -ForegroundColor Cyan
}
Write-Host "Files with metadata preserved: $($OrphanedWithMetadata.Count)"
Write-Host "Runtime: $($Duration.ToString())"
Write-Host "`nIMPORTANT: Test your system before permanently deleting these files!" -ForegroundColor Yellow

# ---- NTFY COMPLETION NOTICE ----
if ($EnableNtfy) {
    $Message = @"
Installer MSP cleanup completed on $env:COMPUTERNAME
Total Installer Size: $([math]::Round($TotalSizeGB, 2)) GB
Orphaned Files Moved: $MovedCount (no metadata only)
Files Preserved: $($OrphanedWithMetadata.Count) (have product names)
Recovered Space: $([math]::Round($OrphanedSizeGB, 2)) GB
ZIP Size: $ZipSizeMB MB
ZIP Location: $ZipPath
Runtime: $($Duration.ToString())
"@
    curl.exe `
        -H "Title: Installer Cleanup Complete" `
        -H "Tags: calendar,package,white_check_mark,recycle" `
        -H "Priority: 3" `
        -d $Message `
        https://ntfy.sh/$NtfyTopic
}
