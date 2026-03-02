<#
.SYNOPSIS
Extracts and lists browser bookmarks for all local users from Chrome and Edge browsers.
.DESCRIPTION
This script iterates through all user profiles on the system and extracts bookmarks from Chrome and Edge browsers.
It processes the bookmarks JSON files and exports them to CSV format for analysis. The output files are saved to
C:\Temp with naming convention showing the browser name and username. Requires the PSSQLite PowerShell module.
#>

# Install the SQLite module (only needed once)
Install-Module -Name PSSQLite -Force -Scope AllUsers

# Import the module
Import-Module PSSQLite

# Create output folder
$OutputFolder = "C:\Temp"
New-Item -Path $OutputFolder -ItemType Directory -Force

# Get all user profiles
$UserProfiles = Get-ChildItem "C:\Users" -Directory | Where-Object { $_.Name -notmatch '^(Public|Default|All Users|Default User)$' }

foreach ($UserProfile in $UserProfiles) {
    $Username = $UserProfile.Name
    
    # Define browser bookmark paths
    $Browsers = @(
        @{
            Name = "Chrome"
            Path = "C:\Users\$Username\AppData\Local\Google\Chrome\User Data\Default\Bookmarks"
        },
        @{
            Name = "Edge"
            Path = "C:\Users\$Username\AppData\Local\Microsoft\Edge\User Data\Default\Bookmarks"
        }
    )
    
    foreach ($Browser in $Browsers) {
        $BrowserName = $Browser.Name
        $BookmarksPath = $Browser.Path
        
        # Check if bookmarks file exists for this user
        if (Test-Path $BookmarksPath) {
            Write-Host "Processing $BrowserName bookmarks for user: $Username"
            
            $OutputFile = "$OutputFolder\$($BrowserName)Bookmarks_$Username.csv"
            
            try {
                # Read the JSON bookmarks file
                $BookmarksJson = Get-Content $BookmarksPath -Raw | ConvertFrom-Json
                
                # Function to recursively extract bookmarks
                function Get-Bookmarks {
                    param($node, $folder = "")
                    
                    $bookmarks = @()
                    
                    if ($node.type -eq "url") {
                        # Convert Chrome timestamp (microseconds since 1601-01-01) to datetime
                        $dateAdded = $null
                        if ($node.date_added) {
                            try {
                                $seconds = [double]$node.date_added / 1000000
                                $dateAdded = ([datetime]'1601-01-01').AddSeconds($seconds).ToLocalTime()
                            }
                            catch {
                                $dateAdded = "Invalid Date"
                            }
                        }
                        
                        $bookmarks += [PSCustomObject]@{
                            Username = $Username
                            Browser = $BrowserName
                            Name = $node.name
                            URL = $node.url
                            Folder = $folder
                            DateAdded = $dateAdded
                        }
                    }
                    
                    if ($node.children) {
                        $currentFolder = if ($folder -eq "") { $node.name } else { "$folder\$($node.name)" }
                        foreach ($child in $node.children) {
                            $bookmarks += Get-Bookmarks -node $child -folder $currentFolder
                        }
                    }
                    
                    return $bookmarks
                }
                
                # Extract bookmarks from all bookmark bars and folders
                $allBookmarks = @()
                
                if ($BookmarksJson.roots.bookmark_bar) {
                    $allBookmarks += Get-Bookmarks -node $BookmarksJson.roots.bookmark_bar -folder "Bookmarks Bar"
                }
                
                if ($BookmarksJson.roots.other) {
                    $allBookmarks += Get-Bookmarks -node $BookmarksJson.roots.other -folder "Other Bookmarks"
                }
                
                if ($BookmarksJson.roots.synced) {
                    $allBookmarks += Get-Bookmarks -node $BookmarksJson.roots.synced -folder "Mobile Bookmarks"
                }
                
                # Export to CSV
                $allBookmarks | Export-Csv -Path $OutputFile -NoTypeInformation
                
                Write-Host "  Saved: $OutputFile ($($allBookmarks.Count) bookmarks)"
            }
            catch {
                Write-Host "  Error processing $BrowserName bookmarks for $Username : $_" -ForegroundColor Red
            }
        }
        else {
            Write-Host "No $BrowserName bookmarks found for user: $Username"
        }
    }
}

Write-Host "`nAll bookmark files saved to: $OutputFolder"
Write-Host "Files created:"
Write-Host "  - ChromeBookmarks_[Username].csv"
Write-Host "  - EdgeBookmarks_[Username].csv"