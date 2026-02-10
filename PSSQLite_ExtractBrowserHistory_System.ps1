<#
.SYNOPSIS
    Extracts Chrome and Edge browser history from all user profiles
.DESCRIPTION
    Queries Chrome and Edge browser history databases for all users on the system.
    Exports browsing history from the past year to CSV files in C:\Temp.
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

# Calculate date one year ago
$OneYearAgo = (Get-Date).AddYears(-1)
$OneYearAgoTimestamp = [Math]::Floor(($OneYearAgo.ToUniversalTime() - [datetime]'1601-01-01').TotalSeconds * 1000000)

foreach ($UserProfile in $UserProfiles) {
    $Username = $UserProfile.Name
    
    # Define browser paths
    $Browsers = @(
        @{
            Name = "Chrome"
            Path = "C:\Users\$Username\AppData\Local\Google\Chrome\User Data\Default\History"
        },
        @{
            Name = "Edge"
            Path = "C:\Users\$Username\AppData\Local\Microsoft\Edge\User Data\Default\History"
        }
    )
    
    foreach ($Browser in $Browsers) {
        $BrowserName = $Browser.Name
        $HistoryPath = $Browser.Path
        
        # Check if browser history exists for this user
        if (Test-Path $HistoryPath) {
            Write-Host "Processing $BrowserName history for user: $Username"
            
            $TempHistory = "$env:TEMP\$($BrowserName)History_$Username"
            $OutputFile = "$OutputFolder\$($BrowserName)History_$Username.csv"
            
            try {
                # Copy the browser history database
                Copy-Item $HistoryPath $TempHistory -Force
                
                # Query the database - get ALL entries from the past year
                $results = Invoke-SqliteQuery -DataSource $TempHistory -Query "SELECT url, title, datetime(last_visit_time/1000000-11644473600,'unixepoch','localtime') as last_visit FROM urls WHERE last_visit_time >= $OneYearAgoTimestamp ORDER BY last_visit_time DESC"
                
                # Add Username and Browser columns to each record
                $results = $results | Select-Object @{Name='Username';Expression={$Username}}, @{Name='Browser';Expression={$BrowserName}}, url, title, last_visit
                
                # Export to CSV
                $results | Export-Csv -Path $OutputFile -NoTypeInformation
                
                # Cleanup
                Remove-Item $TempHistory -ErrorAction SilentlyContinue
                
                Write-Host "  Saved: $OutputFile ($($results.Count) entries)"
            }
            catch {
                Write-Host "  Error processing $BrowserName for $Username : $_" -ForegroundColor Red
            }
        }
        else {
            Write-Host "No $BrowserName history found for user: $Username"
        }
    }
}

Write-Host "`nAll history files saved to: $OutputFolder"
Write-Host "Files created:"
Write-Host "  - ChromeHistory_[Username].csv"
Write-Host "  - EdgeHistory_[Username].csv"