#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Windows Update Management for Immybot

.DESCRIPTION
    Immybot Maintenance Task for automated Windows update management.
    Uses Test/Set methodology with KB-level approval and blocking.
    Preview, Optional, and Beta updates are automatically excluded.
# You'll need to create these or set them below
# this runs as system
.PARAMETER ApprovedKBs
    Comma-separated list of KB numbers to explicitly approve (e.g., "5001234,5001235")
    If specified, ONLY these KBs will be processed
    If empty, all available updates (excluding Preview/Optional/Beta) will be included

.PARAMETER BlockedKBs
    Comma-separated list of KB numbers to explicitly block (e.g., "5001236,5001237")
    These KBs will never be installed regardless of other filters

.PARAMETER MaxUpdates
    Maximum number of updates to install in one run (0 = no limit)
    Only used in Set method

.PARAMETER DownloadOnly
    If true, only download updates without installing them
    Only used in Set method
#>

param(
    [string]$ApprovedKBs = "",
    [string]$BlockedKBs = "",
    [int]$MaxUpdates = 0,
    [bool]$DownloadOnly = $false
)

# Hard-coded exclusion patterns
$hardCodedExclusions = @('Preview', 'Optional', 'Beta')

Function Get-FilteredUpdates {
    param(
        [string]$ApprovedKBs,
        [string]$BlockedKBs
    )
    
    Write-Host "[DEBUG] Starting Get-FilteredUpdates" -ForegroundColor Magenta
    Write-Host "[DEBUG] ApprovedKBs parameter: '$ApprovedKBs'" -ForegroundColor Magenta
    Write-Host "[DEBUG] BlockedKBs parameter: '$BlockedKBs'" -ForegroundColor Magenta
    
    # Check Windows Update service status
    try {
        $wuauserv = Get-Service -Name wuauserv -ErrorAction SilentlyContinue
        if ($wuauserv) {
            Write-Host "[DEBUG] Windows Update Service (wuauserv) Status: $($wuauserv.Status)" -ForegroundColor Magenta
            if ($wuauserv.Status -ne 'Running') {
                Write-Host "[DEBUG] WARNING: Windows Update service is not running. Attempting to start..." -ForegroundColor Yellow
                Start-Service -Name wuauserv -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
                $wuauserv = Get-Service -Name wuauserv
                Write-Host "[DEBUG] Windows Update Service Status after start: $($wuauserv.Status)" -ForegroundColor Magenta
            }
        } else {
            Write-Host "[DEBUG] WARNING: Could not find Windows Update service" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "[DEBUG] Error checking Windows Update service: $_" -ForegroundColor Yellow
    }
    
    # Convert comma-separated strings to arrays - FIX: Handle empty strings properly
    $approvedKBList = @()
    if (-not [string]::IsNullOrWhiteSpace($ApprovedKBs)) {
        $approvedKBList = $ApprovedKBs -split ',' | ForEach-Object { 
            $kb = $_.Trim() -replace '^KB', ''
            if ($kb) { $kb }
        }
    }
    
    $blockedKBList = @()
    if (-not [string]::IsNullOrWhiteSpace($BlockedKBs)) {
        $blockedKBList = $BlockedKBs -split ',' | ForEach-Object { 
            $kb = $_.Trim() -replace '^KB', ''
            if ($kb) { $kb }
        }
    }
    
    Write-Host "[DEBUG] Approved KB List Count: $($approvedKBList.Count)" -ForegroundColor Magenta
    Write-Host "[DEBUG] Approved KBs: $($approvedKBList -join ', ')" -ForegroundColor Magenta
    Write-Host "[DEBUG] Blocked KB List Count: $($blockedKBList.Count)" -ForegroundColor Magenta
    Write-Host "[DEBUG] Blocked KBs: $($blockedKBList -join ', ')" -ForegroundColor Magenta
    
    # Create COM objects for Windows Update
    Write-Host "[DEBUG] Creating Windows Update COM objects..." -ForegroundColor Magenta
    $updateSession = New-Object -ComObject Microsoft.Update.Session
    $updateSearcher = $updateSession.CreateUpdateSearcher()
    
    # Search for updates - this can take several minutes!
    $searchCriteria = "IsInstalled=0 and IsHidden=0 and Type='Software'"
    Write-Host "[DEBUG] Searching for updates with criteria: $searchCriteria" -ForegroundColor Magenta
    Write-Host "[DEBUG] This may take 2-5 minutes, please wait..." -ForegroundColor Yellow
    
    $searchStartTime = Get-Date
    
    try {
        # The Search() method is synchronous and will block until complete
        $searchResult = $updateSearcher.Search($searchCriteria)
        
        $searchEndTime = Get-Date
        $searchDuration = ($searchEndTime - $searchStartTime).TotalSeconds
        
        Write-Host "[DEBUG] Search completed in $([math]::Round($searchDuration, 1)) seconds" -ForegroundColor Magenta
        Write-Host "[DEBUG] Total updates found: $($searchResult.Updates.Count)" -ForegroundColor Magenta
    }
    catch {
        Write-Host "[DEBUG] Search failed with error: $_" -ForegroundColor Red
        Write-Host "[DEBUG] Error details: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
    
    $filteredUpdates = @{
        UpdatesToProcess = New-Object -ComObject Microsoft.Update.UpdateColl
        TotalAvailable = $searchResult.Updates.Count
        UpdateDetails = @()
    }
    
    # NEW APPROACH: Get all updates first, then filter
    foreach ($update in $searchResult.Updates) {
        $title = $update.Title
        
        Write-Host "[DEBUG] Processing update: $title" -ForegroundColor Magenta
        
        # Extract KB number
        $kbNumber = ""
        if ($update.KBArticleIDs.Count -gt 0) {
            $kbNumber = $update.KBArticleIDs[0]
        }
        Write-Host "[DEBUG]   KB Number: $kbNumber" -ForegroundColor Magenta
        
        # Check for hard-coded exclusions
        $isHardCodedExclusion = $false
        foreach ($exclusion in $hardCodedExclusions) {
            if ($title -match $exclusion) {
                $isHardCodedExclusion = $true
                Write-Host "[DEBUG]   Matched hard-coded exclusion: $exclusion" -ForegroundColor Magenta
                break
            }
        }
        
        # Check blocked KBs
        $isBlocked = $false
        if ($blockedKBList.Count -gt 0 -and $kbNumber -ne "" -and $blockedKBList -contains $kbNumber) {
            $isBlocked = $true
            Write-Host "[DEBUG]   Update is BLOCKED" -ForegroundColor Magenta
        }
        
        # Determine if update should be included
        $shouldInclude = $false
        
        # FIXED LOGIC: Check if we're in "approved mode" or "all updates mode"
        if ($approvedKBList.Count -gt 0) {
            # Approved KB mode - only include if KB is in approved list
            Write-Host "[DEBUG]   Mode: Approved KB List" -ForegroundColor Magenta
            if ($kbNumber -ne "" -and $approvedKBList -contains $kbNumber) {
                $shouldInclude = $true
                Write-Host "[DEBUG]   KB IS in approved list - INCLUDE" -ForegroundColor Magenta
            } else {
                Write-Host "[DEBUG]   KB NOT in approved list - EXCLUDE" -ForegroundColor Magenta
            }
        } else {
            # All updates mode - include everything except hard-coded exclusions
            Write-Host "[DEBUG]   Mode: All Updates (no approved list)" -ForegroundColor Magenta
            if (-not $isHardCodedExclusion) {
                $shouldInclude = $true
                Write-Host "[DEBUG]   Not a hard-coded exclusion - INCLUDE" -ForegroundColor Magenta
            } else {
                Write-Host "[DEBUG]   Is a hard-coded exclusion - EXCLUDE" -ForegroundColor Magenta
            }
        }
        
        # Always exclude blocked KBs
        if ($isBlocked) {
            $shouldInclude = $false
            Write-Host "[DEBUG]   Blocked KB overrides - EXCLUDE" -ForegroundColor Magenta
        }
        
        # Determine status
        $status = "Excluded"
        if ($isBlocked) {
            $status = "Blocked"
        } elseif ($isHardCodedExclusion) {
            $status = "Excluded (Preview/Optional/Beta)"
        } elseif ($shouldInclude) {
            $status = "Pending Install"
        }
        
        Write-Host "[DEBUG]   Final Status: $status (ShouldInclude: $shouldInclude)" -ForegroundColor Magenta
        
        # Collect metadata
        $updateInfo = [PSCustomObject]@{
            Title = $title
            KB = if ($kbNumber) { "KB$kbNumber" } else { "N/A" }
            Size = "{0:N2} MB" -f ($update.MaxDownloadSize / 1MB)
            Severity = $update.MsrcSeverity
            RebootRequired = $update.RebootRequired
            Status = $status
            ShouldInclude = $shouldInclude
        }
        
        $filteredUpdates.UpdateDetails += $updateInfo
        
        # Add to collection if it should be included
        if ($shouldInclude) {
            Write-Host "[DEBUG]   Adding to UpdatesToProcess collection" -ForegroundColor Magenta
            $filteredUpdates.UpdatesToProcess.Add($update) | Out-Null
        }
    }
    
    Write-Host "[DEBUG] Final UpdatesToProcess Count: $($filteredUpdates.UpdatesToProcess.Count)" -ForegroundColor Magenta
    
    return $filteredUpdates
}

switch ($method) {
    "get" {
        Write-Host "=== Getting Windows Update State ===" -ForegroundColor Cyan
        
        try {
            $result = Get-FilteredUpdates -ApprovedKBs $ApprovedKBs -BlockedKBs $BlockedKBs
            
            Write-Host "`nUpdate Status:" -ForegroundColor Cyan
            $result.UpdateDetails | Format-Table -AutoSize
            
            return $result.UpdateDetails
        }
        catch {
            Write-Host "Error getting update state: $_" -ForegroundColor Red
            Write-Host $_.ScriptStackTrace -ForegroundColor Red
            throw
        }
    }
    
    "set" {
        Write-Host "=== Windows Update Installation ===" -ForegroundColor Cyan
        
        try {
            # Convert comma-separated strings to arrays for display
            $approvedKBList = @()
            if (-not [string]::IsNullOrWhiteSpace($ApprovedKBs)) {
                $approvedKBList = $ApprovedKBs -split ',' | ForEach-Object { 
                    $kb = $_.Trim() -replace '^KB', ''
                    if ($kb) { $kb }
                }
            }
            
            $blockedKBList = @()
            if (-not [string]::IsNullOrWhiteSpace($BlockedKBs)) {
                $blockedKBList = $BlockedKBs -split ',' | ForEach-Object { 
                    $kb = $_.Trim() -replace '^KB', ''
                    if ($kb) { $kb }
                }
            }
            
            if ($approvedKBList.Count -gt 0) {
                Write-Host "Mode: Approved KB List Only" -ForegroundColor Cyan
                Write-Host "Approved KBs: $($approvedKBList -join ', ')" -ForegroundColor Green
            } else {
                Write-Host "Mode: All Updates (excluding Preview/Optional/Beta)" -ForegroundColor Cyan
            }
            
            if ($blockedKBList.Count -gt 0) {
                Write-Host "Blocked KBs: $($blockedKBList -join ', ')" -ForegroundColor Red
            }
            
            Write-Host "Max updates: $(if ($MaxUpdates -eq 0) { 'Unlimited' } else { $MaxUpdates })" -ForegroundColor White
            Write-Host "Action: $(if ($DownloadOnly) { 'Download Only' } else { 'Download and Install' })" -ForegroundColor White
            Write-Host ""
            
            $result = Get-FilteredUpdates -ApprovedKBs $ApprovedKBs -BlockedKBs $BlockedKBs
            
            Write-Host "Found $($result.TotalAvailable) total updates available." -ForegroundColor Yellow
            
            # Display filtered updates
            foreach ($updateInfo in $result.UpdateDetails) {
                if ($updateInfo.ShouldInclude) {
                    $statusTag = if ($approvedKBList.Count -gt 0) { "[APPROVED KB]" } else { "[+]" }
                    Write-Host "  $statusTag $($updateInfo.Title)" -ForegroundColor Green
                    Write-Host "      KB: $($updateInfo.KB) | Size: $($updateInfo.Size) | Severity: $($updateInfo.Severity)" -ForegroundColor Gray
                }
                elseif ($updateInfo.Status -eq "Blocked") {
                    Write-Host "  [BLOCKED] $($updateInfo.Title) (KB: $($updateInfo.KB))" -ForegroundColor Red
                }
                elseif ($updateInfo.Status -eq "Excluded (Preview/Optional/Beta)") {
                    Write-Host "  [-] Auto-excluded: $($updateInfo.Title) (Preview/Optional/Beta)" -ForegroundColor DarkGray
                }
            }
            
            # Apply MaxUpdates limit if specified
            if ($MaxUpdates -gt 0 -and $result.UpdatesToProcess.Count -gt $MaxUpdates) {
                Write-Host "`nApplying MaxUpdates limit: Reducing from $($result.UpdatesToProcess.Count) to $MaxUpdates updates" -ForegroundColor Yellow
                $limitedUpdates = New-Object -ComObject Microsoft.Update.UpdateColl
                for ($i = 0; $i -lt $MaxUpdates; $i++) {
                    $limitedUpdates.Add($result.UpdatesToProcess.Item($i)) | Out-Null
                }
                $result.UpdatesToProcess = $limitedUpdates
            }
            
            Write-Host ""
            Write-Host "Processing $($result.UpdatesToProcess.Count) update(s)." -ForegroundColor Cyan
            
            if ($result.UpdatesToProcess.Count -eq 0) {
                Write-Host "No updates to process." -ForegroundColor Green
                return
            }
            
            # Download updates
            Write-Host "`nDownloading $($result.UpdatesToProcess.Count) update(s)..." -ForegroundColor Yellow
            $updateSession = New-Object -ComObject Microsoft.Update.Session
            $downloader = $updateSession.CreateUpdateDownloader()
            $downloader.Updates = $result.UpdatesToProcess
            $downloadResult = $downloader.Download()
            
            if ($downloadResult.ResultCode -eq 2) {
                Write-Host "Download completed successfully." -ForegroundColor Green
            } else {
                Write-Host "Download completed with result code: $($downloadResult.ResultCode)" -ForegroundColor Yellow
            }
            
            # Stop here if download-only mode
            if ($DownloadOnly) {
                Write-Host "`nDownload-only mode: Updates downloaded but not installed." -ForegroundColor Cyan
                return
            }
            
            # Install updates
            Write-Host "`nInstalling updates..." -ForegroundColor Yellow
            $installer = $updateSession.CreateUpdateInstaller()
            $installer.Updates = $result.UpdatesToProcess
            $installResult = $installer.Install()
            
            # Report results
            Write-Host "`n=== Installation Results ===" -ForegroundColor Cyan
            Write-Host "Result Code: $($installResult.ResultCode)" -ForegroundColor White
            Write-Host "Reboot Required: $($installResult.RebootRequired)" -ForegroundColor $(if ($installResult.RebootRequired) { "Yellow" } else { "Green" })
            
            switch ($installResult.ResultCode) {
                2 { Write-Host "Status: Installation succeeded!" -ForegroundColor Green }
                3 { Write-Host "Status: Installation succeeded with errors" -ForegroundColor Yellow }
                4 { 
                    Write-Host "Status: Installation failed" -ForegroundColor Red
                    throw "Windows Update installation failed"
                }
                5 { 
                    Write-Host "Status: Installation aborted" -ForegroundColor Red
                    throw "Windows Update installation was aborted"
                }
                default { Write-Host "Status: Unknown result code" -ForegroundColor Yellow }
            }
            
            if ($installResult.RebootRequired) {
                Write-Host "`nNote: Reboot required for updates to complete. Immybot will handle this based on deployment settings." -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "Error during update installation: $_" -ForegroundColor Red
            Write-Host $_.ScriptStackTrace -ForegroundColor Red
            throw
        }
    }
    
    "test" {
        Write-Host "=== Windows Update Compliance Check ===" -ForegroundColor Cyan
        
        try {
            # Convert comma-separated strings to arrays for display
            $approvedKBList = @()
            if (-not [string]::IsNullOrWhiteSpace($ApprovedKBs)) {
                $approvedKBList = $ApprovedKBs -split ',' | ForEach-Object { 
                    $kb = $_.Trim() -replace '^KB', ''
                    if ($kb) { $kb }
                }
            }
            
            $blockedKBList = @()
            if (-not [string]::IsNullOrWhiteSpace($BlockedKBs)) {
                $blockedKBList = $BlockedKBs -split ',' | ForEach-Object { 
                    $kb = $_.Trim() -replace '^KB', ''
                    if ($kb) { $kb }
                }
            }
            
            if ($approvedKBList.Count -gt 0) {
                Write-Host "Mode: Approved KB List Only" -ForegroundColor Cyan
                Write-Host "Approved KBs: $($approvedKBList -join ', ')" -ForegroundColor Green
            } else {
                Write-Host "Mode: All Updates (excluding Preview/Optional/Beta)" -ForegroundColor Cyan
            }
            
            if ($blockedKBList.Count -gt 0) {
                Write-Host "Blocked KBs: $($blockedKBList -join ', ')" -ForegroundColor Red
            }
            Write-Host ""
            
            $result = Get-FilteredUpdates -ApprovedKBs $ApprovedKBs -BlockedKBs $BlockedKBs
            
            Write-Host "Found $($result.TotalAvailable) total updates available." -ForegroundColor Yellow
            
            $updatesNeeded = $result.UpdatesToProcess.Count
            
            # Display updates that need installation
            foreach ($updateInfo in $result.UpdateDetails | Where-Object { $_.ShouldInclude }) {
                Write-Host "  [Needs Install] $($updateInfo.Title)" -ForegroundColor Yellow
                Write-Host "      KB: $($updateInfo.KB)" -ForegroundColor Gray
            }
            
            Write-Host ""
            
            if ($updatesNeeded -eq 0) {
                Write-Host "All applicable updates are installed - System is compliant." -ForegroundColor Green
                return $true
            } else {
                Write-Host "$updatesNeeded update(s) need to be installed - System is non-compliant." -ForegroundColor Yellow
                return $false
            }
        }
        catch {
            Write-Host "Error during compliance check: $_" -ForegroundColor Red
            Write-Host $_.ScriptStackTrace -ForegroundColor Red
            # Return false on error to trigger remediation
            return $false
        }
    }
}