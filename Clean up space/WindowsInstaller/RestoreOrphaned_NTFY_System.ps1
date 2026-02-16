<#
.SYNOPSIS
    Restores MSP files from quarantine folders or ZIPs back to Windows Installer
.DESCRIPTION
    Searches for quarantine folders and ZIP archives containing orphaned MSP files.
    Allows user to select and restore files back to C:\Windows\Installer with ntfy notifications.
#>

# CONFIGURATION - CHANGE THIS!!!
$ntfyTopic = "Insertyourtopicnamehere"
$ntfyServer = "https://ntfy.sh"

# -------------------------------
# Restore MSP Files from Quarantine ZIPs
# + ntfy notifications
# -------------------------------

$QuarantineSearchPath = "C:\Temp"
$EnableNtfy = $true
$StartTime = Get-Date

Write-Host "Searching for quarantine archives in $QuarantineSearchPath..." -ForegroundColor Cyan

# Find all quarantine folders and ZIPs
$QuarantineFolders = Get-ChildItem -Path $QuarantineSearchPath -Directory -Filter "Installer_Orphaned_*" -ErrorAction SilentlyContinue
$QuarantineZips = Get-ChildItem -Path $QuarantineSearchPath -File -Filter "Installer_Orphaned_*.zip" -ErrorAction SilentlyContinue

$AllQuarantines = @()

# Add folders
foreach ($Folder in $QuarantineFolders) {
    $FileCount = (Get-ChildItem -Path $Folder.FullName -Filter *.msp -ErrorAction SilentlyContinue).Count
    $SizeMB = [math]::Round((Get-ChildItem -Path $Folder.FullName -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
    
    $AllQuarantines += [PSCustomObject]@{
        Index    = $AllQuarantines.Count + 1
        Type     = "Folder"
        Name     = $Folder.Name
        Path     = $Folder.FullName
        SizeMB   = $SizeMB
        Files    = $FileCount
        Created  = $Folder.CreationTime
    }
}

# Add ZIPs
foreach ($Zip in $QuarantineZips) {
    $SizeMB = [math]::Round($Zip.Length / 1MB, 2)
    
    $AllQuarantines += [PSCustomObject]@{
        Index    = $AllQuarantines.Count + 1
        Type     = "ZIP"
        Name     = $Zip.Name
        Path     = $Zip.FullName
        SizeMB   = $SizeMB
        Files    = "?"
        Created  = $Zip.CreationTime
    }
}

if ($AllQuarantines.Count -eq 0) {
    Write-Host "`nNo quarantine archives found in $QuarantineSearchPath" -ForegroundColor Yellow
    
    if ($EnableNtfy) {
        $Message = @"
MSP Restore: No quarantine archives found
Search path: $QuarantineSearchPath
Computer: $env:COMPUTERNAME
"@
        curl.exe `
            -H "Title: No Quarantine Archives Found" `
            -H "Tags: warning,package" `
            -H "Priority: 3" `
            -d $Message `
            "$ntfyServer/$ntfyTopic"
    }
    exit
}

# Display available quarantines
Write-Host "`n--- AVAILABLE QUARANTINE ARCHIVES ---" -ForegroundColor Cyan
$AllQuarantines | Format-Table Index, Type, Name, SizeMB, Files, Created -AutoSize

# Prompt for selection
Write-Host "`nEnter the Index number to restore (or 'q' to quit): " -ForegroundColor Yellow -NoNewline
$Selection = Read-Host

if ($Selection -eq 'q') {
    Write-Host "Cancelled." -ForegroundColor Red
    
    if ($EnableNtfy) {
        $Message = @"
MSP Restore cancelled by user
Computer: $env:COMPUTERNAME
Available archives: $($AllQuarantines.Count)
"@
        curl.exe `
            -H "Title: MSP Restore Cancelled" `
            -H "Tags: info,package" `
            -H "Priority: 2" `
            -d $Message `
            "$ntfyServer/$ntfyTopic"
    }
    exit
}

$SelectedItem = $AllQuarantines | Where-Object { $_.Index -eq [int]$Selection }

if (-not $SelectedItem) {
    Write-Host "`nInvalid selection!" -ForegroundColor Red
    exit
}

Write-Host "`nSelected: $($SelectedItem.Name)" -ForegroundColor Cyan

# If ZIP, extract it first
$SourcePath = $SelectedItem.Path
if ($SelectedItem.Type -eq "ZIP") {
    $ExtractPath = $SourcePath -replace '\.zip$', ''
    
    if (Test-Path $ExtractPath) {
        Write-Host "Extracted folder already exists at: $ExtractPath" -ForegroundColor Yellow
        Write-Host "Using existing folder..." -ForegroundColor Cyan
        $SourcePath = $ExtractPath
    } else {
        Write-Host "Extracting ZIP archive..." -ForegroundColor Cyan
        try {
            Expand-Archive -Path $SelectedItem.Path -DestinationPath $ExtractPath -Force
            Write-Host "ZIP extracted successfully!" -ForegroundColor Green
            $SourcePath = $ExtractPath
        } catch {
            Write-Host "Failed to extract ZIP: $_" -ForegroundColor Red
            
            if ($EnableNtfy) {
                $Message = @"
MSP Restore FAILED - ZIP extraction error
Archive: $($SelectedItem.Name)
Error: $_
Computer: $env:COMPUTERNAME
"@
                curl.exe `
                    -H "Title: MSP Restore Failed" `
                    -H "Tags: x,package,warning" `
                    -H "Priority: 4" `
                    -d $Message `
                    "$ntfyServer/$ntfyTopic"
            }
            exit
        }
    }
}

# Get files to restore
$FilesToRestore = Get-ChildItem -Path $SourcePath -Filter *.msp -ErrorAction SilentlyContinue

if ($FilesToRestore.Count -eq 0) {
    Write-Host "`nNo MSP files found in selected archive!" -ForegroundColor Red
    
    if ($EnableNtfy) {
        $Message = @"
MSP Restore FAILED - No MSP files found
Archive: $($SelectedItem.Name)
Computer: $env:COMPUTERNAME
"@
        curl.exe `
            -H "Title: MSP Restore Failed" `
            -H "Tags: x,package,warning" `
            -H "Priority: 4" `
            -d $Message `
            "$ntfyServer/$ntfyTopic"
    }
    exit
}
Write-Host "`nFound $($FilesToRestore.Count) MSP files to restore:" -ForegroundColor Cyan
$FilesToRestore | Format-Table Name, @{Label="SizeMB";Expression={[math]::Round($_.Length / 1MB, 2)}} -AutoSize

# Confirmation
Write-Host "`nRestore these files to C:\Windows\Installer?" -ForegroundColor Yellow
Write-Host "Type 'yes' to proceed: " -ForegroundColor Yellow -NoNewline
$Confirmation = Read-Host

if ($Confirmation.ToLower() -ne "yes") {
    Write-Host "`nOperation cancelled." -ForegroundColor Red
    
    if ($EnableNtfy) {
        $Message = @"
MSP Restore cancelled by user (after selection)
Archive: $($SelectedItem.Name)
Files available: $($FilesToRestore.Count)
Computer: $env:COMPUTERNAME
"@
        curl.exe `
            -H "Title: MSP Restore Cancelled" `
            -H "Tags: info,package" `
            -H "Priority: 2" `
            -d $Message `
            "$ntfyServer/$ntfyTopic"
    }
    exit
}

# Restore files
$InstallerPath = "C:\Windows\Installer"
Write-Host "`nRestoring files..." -ForegroundColor Cyan
$RestoredCount = 0
$FailedCount = 0

foreach ($File in $FilesToRestore) {
    try {
        Copy-Item -Path $File.FullName -Destination $InstallerPath -Force
        $RestoredCount++
        Write-Host "✓ Restored: $($File.Name)" -ForegroundColor Green
    } catch {
        Write-Host "✗ Failed: $($File.Name) - $_" -ForegroundColor Red
        $FailedCount++
    }
}

# Calculate runtime
$Duration = New-TimeSpan -Start $StartTime -End (Get-Date)

# Summary
Write-Host "`n--- RESTORATION SUMMARY ---" -ForegroundColor Green
Write-Host "Files restored: $RestoredCount of $($FilesToRestore.Count)"
Write-Host "Failed: $FailedCount"
Write-Host "Runtime: $($Duration.ToString())"

if ($RestoredCount -gt 0) {
    Write-Host "`nFiles successfully restored to C:\Windows\Installer!" -ForegroundColor Green
    Write-Host "Quarantine archive preserved at: $($SelectedItem.Path)" -ForegroundColor Cyan
    
    # Send success notification
    if ($EnableNtfy) {
        $TotalSizeMB = ($FilesToRestore | Measure-Object -Property Length -Sum).Sum / 1MB
        $Message = @"
MSP Restore completed successfully on $env:COMPUTERNAME
Archive: $($SelectedItem.Name)
Files restored: $RestoredCount of $($FilesToRestore.Count)
Failed: $FailedCount
Size restored: $([math]::Round($TotalSizeMB, 2)) MB
Runtime: $($Duration.ToString())
"@
        curl.exe `
            -H "Title: MSP Restore Complete" `
            -H "Tags: white_check_mark,package,recycle" `
            -H "Priority: 3" `
            -d $Message `
            "$ntfyServer/$ntfyTopic"
    }
} else {
    Write-Host "`nNo files were restored!" -ForegroundColor Red
    
    # Send failure notification
    if ($EnableNtfy) {
        $Message = @"
MSP Restore FAILED on $env:COMPUTERNAME
Archive: $($SelectedItem.Name)
All restore attempts failed
Failed count: $FailedCount
Runtime: $($Duration.ToString())
"@
        curl.exe `
            -H "Title: MSP Restore Failed" `
            -H "Tags: x,package,warning" `
            -H "Priority: 4" `
            -d $Message `
            "$ntfyServer/$ntfyTopic"
    }
}
