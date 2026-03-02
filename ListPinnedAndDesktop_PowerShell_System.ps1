<#
.SYNOPSIS
Lists pinned taskbar items and desktop files for all user profiles.
.DESCRIPTION
This script enumerates all user profiles on the system and retrieves their desktop items and taskbar-pinned application shortcuts. The results are displayed in the console by user and location, and exported to a CSV file in C:\Temp for further analysis.
#>

# Create output folder
$OutputFolder = "C:\Temp"
New-Item -Path $OutputFolder -ItemType Directory -Force

# Get all user profiles
$UserProfiles = Get-ChildItem "C:\Users" -Directory | Where-Object { $_.Name -notmatch '^(Public|Default|All Users|Default User)$' }

$AllResults = @()

foreach ($UserProfile in $UserProfiles) {
    $Username = $UserProfile.Name
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Processing User: $Username" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    # Desktop Items
    Write-Host "`nDESKTOP ITEMS:" -ForegroundColor Yellow
    $DesktopPath = "C:\Users\$Username\Desktop"
    
    if (Test-Path $DesktopPath) {
        $DesktopItems = Get-ChildItem -Path $DesktopPath -Force -ErrorAction SilentlyContinue
        
        foreach ($item in $DesktopItems) {
            Write-Host "  $($item.Name)"
            
            $AllResults += [PSCustomObject]@{
                Username = $Username
                Location = "Desktop"
                Name = $item.Name
                Type = if ($item.PSIsContainer) { "Folder" } else { $item.Extension }
                FullPath = $item.FullName
                DateModified = $item.LastWriteTime
            }
        }
    }
    else {
        Write-Host "  Desktop path not found" -ForegroundColor Red
    }
    
    # Taskbar Pinned Items
    Write-Host "`nTASKBAR PINNED ITEMS:" -ForegroundColor Yellow
    $TaskbarPinsPath = "C:\Users\$Username\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
    
    if (Test-Path $TaskbarPinsPath) {
        $TaskbarItems = Get-ChildItem -Path $TaskbarPinsPath -Filter *.lnk -ErrorAction SilentlyContinue
        
        foreach ($item in $TaskbarItems) {
            Write-Host "  $($item.Name)"
            
            $AllResults += [PSCustomObject]@{
                Username = $Username
                Location = "Taskbar"
                Name = $item.Name
                Type = "Shortcut"
                FullPath = $item.FullName
                DateModified = $item.LastWriteTime
            }
        }
    }
    else {
        Write-Host "  No taskbar pins found" -ForegroundColor Gray
    }
    
    # Start Menu Pinned Items
    Write-Host "`nSTART MENU PINNED ITEMS:" -ForegroundColor Yellow
    $StartMenuPinsPath = "C:\Users\$Username\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\StartMenu"
    
    if (Test-Path $StartMenuPinsPath) {
        $StartMenuItems = Get-ChildItem -Path $StartMenuPinsPath -Filter *.lnk -ErrorAction SilentlyContinue
        
        foreach ($item in $StartMenuItems) {
            Write-Host "  $($item.Name)"
            
            $AllResults += [PSCustomObject]@{
                Username = $Username
                Location = "Start Menu"
                Name = $item.Name
                Type = "Shortcut"
                FullPath = $item.FullName
                DateModified = $item.LastWriteTime
            }
        }
    }
    else {
        Write-Host "  No start menu pins found" -ForegroundColor Gray
    }
}

# Export to CSV
$OutputFile = "$OutputFolder\DesktopAndPins_AllUsers.csv"
$AllResults | Export-Csv -Path $OutputFile -NoTypeInformation

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "Results saved to: $OutputFile" -ForegroundColor Green
Write-Host "Total items found: $($AllResults.Count)" -ForegroundColor Green
Write-Host "Total users processed: $($UserProfiles.Count)" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green