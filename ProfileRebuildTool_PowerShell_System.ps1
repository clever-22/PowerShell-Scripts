# ============================================================
# Interactive User Profile Rebuild Tool (v2)
# Run as Administrator
# ============================================================

function Get-UserProfiles {
    Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" |
        ForEach-Object {
            $sid  = $_.PSChildName
            $path = (Get-ItemProperty $_.PsPath -ErrorAction SilentlyContinue).ProfileImagePath
            if ($path -and $path -like "C:\Users\*") {
                [PSCustomObject]@{
                    SID         = $sid
                    ProfilePath = $path
                    KeyPath     = $_.PsPath
                }
            }
        }
}

Write-Host "`n=== USER PROFILE REBUILD TOOL ===" -ForegroundColor Cyan

# --- Step 0: Mode ---
Write-Host "`nWhat do you want to do?" -ForegroundColor Cyan
Write-Host "  [1] List ALL user profiles"
Write-Host "  [2] Search for a user"
Write-Host "  [Q] Quit"
$mode = Read-Host "`nChoice"
if ($mode -match '^[Qq]$') { Write-Host "Cancelled." -ForegroundColor Yellow; return }

# --- Step 1: Pull profiles ---
$allProfiles = Get-UserProfiles
if (-not $allProfiles) {
    Write-Host "No user profiles found." -ForegroundColor Red
    return
}

# --- Step 2: Filter ---
$filtered = $null
switch ($mode) {
    '1' { $filtered = $allProfiles }
    '2' {
        $search = Read-Host "Enter username (or partial name) to search"
        if ([string]::IsNullOrWhiteSpace($search)) {
            Write-Host "No search term provided." -ForegroundColor Red
            return
        }
        $filtered = $allProfiles | Where-Object { $_.ProfilePath -like "*$search*" }
        if (-not $filtered) {
            Write-Host "No profiles match '$search'." -ForegroundColor Red
            return
        }
    }
    default {
        Write-Host "Invalid choice." -ForegroundColor Red
        return
    }
}

# --- Step 3: Group by folder (so .bak SIDs cluster under the same user) ---
$grouped = $filtered | Group-Object { ($_.ProfilePath -replace '\\$','') }

# --- Step 4: Menu ---
Write-Host "`n--- Matching Profiles ---" -ForegroundColor Cyan
$i = 1
$menu = @{}
foreach ($g in $grouped) {
    $folder = $g.Name
    $sids   = ($g.Group | ForEach-Object { $_.SID }) -join ", "
    Write-Host ("[{0}] {1}" -f $i, $folder) -ForegroundColor Yellow
    Write-Host ("     SIDs: $sids") -ForegroundColor DarkGray
    $menu[$i] = $g.Group
    $i++
}

Write-Host ""
$choice = Read-Host "Enter the number of the profile to rebuild (or Q to quit)"
if ($choice -match '^[Qq]$') { Write-Host "Cancelled." -ForegroundColor Yellow; return }
if (-not $menu.ContainsKey([int]$choice)) {
    Write-Host "Invalid selection." -ForegroundColor Red
    return
}

$selected      = $menu[[int]$choice]
$profileFolder = ($selected[0].ProfilePath)
$renameTarget  = "$profileFolder.old"
$baseName      = Split-Path $profileFolder -Leaf

Write-Host "`n--- SELECTED ---" -ForegroundColor Cyan
Write-Host "Profile folder : $profileFolder"
Write-Host "Will rename to : $renameTarget"
Write-Host "SIDs detected  :"
$selected | ForEach-Object { Write-Host "   $($_.SID)" }
Write-Host ""

# --- Step 5: Show sessions ---
Write-Host "Active sessions:" -ForegroundColor Cyan
try { query user } catch { Write-Host "No active sessions found." -ForegroundColor DarkGray }
Write-Host ""

# --- Step 6: Rename ---
$confirm = Read-Host "Rename folder '$profileFolder' to '$renameTarget'? (Y/N)"
if ($confirm -match '^[Yy]$') {
    try {
        if (Test-Path $renameTarget) {
            Write-Host "Target '$renameTarget' already exists. Skipping rename." -ForegroundColor Yellow
        } elseif (-not (Test-Path $profileFolder)) {
            Write-Host "Source folder '$profileFolder' not found. Skipping rename." -ForegroundColor Yellow
        } else {
            Rename-Item -Path $profileFolder -NewName (Split-Path $renameTarget -Leaf) -ErrorAction Stop
            Write-Host "OK - Folder renamed." -ForegroundColor Green
        }
    } catch {
        Write-Host "FAIL - Rename failed: $_" -ForegroundColor Red
    }
} else {
    Write-Host "Skipped folder rename." -ForegroundColor Yellow
}

# --- Step 7: Refresh SIDs (in case path changed after rename) ---
Write-Host "`nRe-scanning registry for related SIDs..." -ForegroundColor Cyan
$sidsToDelete = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" |
    Where-Object {
        $p = (Get-ItemProperty $_.PsPath -ErrorAction SilentlyContinue).ProfileImagePath
        $p -like "*\$baseName" -or $p -like "*\$baseName.old"
    }

if (-not $sidsToDelete) {
    Write-Host "No SID entries found for '$baseName'. Registry may already be clean." -ForegroundColor Yellow
} else {
    Write-Host "Found SID entries:" -ForegroundColor Cyan
    $sidsToDelete | ForEach-Object {
        $p = (Get-ItemProperty $_.PsPath -ErrorAction SilentlyContinue).ProfileImagePath
        Write-Host "   $($_.PSChildName)  →  $p" -ForegroundColor DarkGray
    }
    Write-Host ""
    $confirm2 = Read-Host "Delete the above SID key(s)? (Y/N)"
    if ($confirm2 -match '^[Yy]$') {
        foreach ($key in $sidsToDelete) {
            try {
                Remove-Item $key.PsPath -Recurse -Force -ErrorAction Stop
                Write-Host "OK - Removed SID: $($key.PSChildName)" -ForegroundColor Green
            } catch {
                Write-Host "FAIL - Could not remove $($key.PSChildName): $_" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "Skipped registry cleanup." -ForegroundColor Yellow
    }
}

# --- Step 8: Reboot ---
Write-Host ""
$reboot = Read-Host "Reboot now to finalize? (Y/N)"
if ($reboot -match '^[Yy]$') {
    Write-Host "Rebooting in 5 seconds..." -ForegroundColor Cyan
    Start-Sleep -Seconds 5
    Restart-Computer -Force
} else {
    Write-Host "Reboot skipped. Remember to reboot before the user signs in!" -ForegroundColor Yellow
}