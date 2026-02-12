<#
.SYNOPSIS
    Lists all browser extensions installed in Chrome and Edge
.DESCRIPTION
    Scans Chrome and Edge user profile directories to enumerate all installed extensions.
    Extracts extension metadata including name, ID, version, and description.
    Exports results to a JSON file for documentation and inventory purposes.
#>

# Run this in User Context
# Set output directory and file path
$outputDir = "C:\Temp"
$outputFile = "$outputDir\browser-extensions.json"

# Ensure output directory exists
if (-not (Test-Path -Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

# Initialize an empty array list
$allExtensions = New-Object System.Collections.ArrayList

# Function to read Chrome/Edge manifests
function Get-ChromiumExtensions {
    param (
        [string]$BrowserName,
        [string]$BrowserPath
    )
    
    if (Test-Path -Path $BrowserPath) {
        Write-Host "Scanning $BrowserName extensions..." -ForegroundColor Cyan
        
        $extensions = Get-ChildItem -Path $BrowserPath -Directory
        foreach ($extension in $extensions) {
            $ExtID = $extension.Name
            $versionFolders = Get-ChildItem -Path $extension.FullName -Directory
            
            if ($versionFolders.Count -gt 0) {
                # Get the latest version folder
                $latestVersion = $versionFolders | Sort-Object -Property Name -Descending | Select-Object -First 1
                $manifestPath = Join-Path $latestVersion.FullName "manifest.json"
                
                if (Test-Path $manifestPath) {
                    try {
                        $manifest = Get-Content -Path $manifestPath -Raw | ConvertFrom-Json
                        $extensionData = [PSCustomObject]@{
                            Browser = $BrowserName
                            Name = $manifest.name
                            ID = $ExtID
                            Version = $manifest.version
                            Description = $manifest.description
                        }
                        
                        # Properly add the object to the ArrayList
                        [void]$allExtensions.Add($extensionData)

                        # Display progress
                        Write-Host "Found: $($extensionData.Name)" -ForegroundColor Green
                    } catch {
                        Write-Host "Error processing $ExtID in $BrowserName : $_" -ForegroundColor Red
                    }
                }
            }
        }
    } else {
        Write-Host "$BrowserName not found or no extensions installed." -ForegroundColor Yellow
    }
}

# Function to read Firefox extensions
function Get-FirefoxExtensions {
    $firefoxProfilesPath = "$env:APPDATA\Mozilla\Firefox\Profiles"
    
    if (Test-Path -Path $firefoxProfilesPath) {
        Write-Host "Scanning Firefox extensions..." -ForegroundColor Cyan
        
        $profiles = Get-ChildItem -Path $firefoxProfilesPath -Directory
        foreach ($profile in $profiles) {
            # Check extensions.json first (newer Firefox versions)
            $extensionsJsonPath = Join-Path $profile.FullName "extensions.json"
            if (Test-Path $extensionsJsonPath) {
                try {
                    $extensionsData = Get-Content -Path $extensionsJsonPath -Raw | ConvertFrom-Json
                    foreach ($addon in $extensionsData.addons) {
                        $extensionData = [PSCustomObject]@{
                            Browser = "Firefox"
                            Name = $addon.defaultLocale.name
                            ID = $addon.id
                            Version = $addon.version
                            Description = $addon.defaultLocale.description
                        }

                        # Properly add the object to the ArrayList
                        [void]$allExtensions.Add($extensionData)

                        # Display progress
                        Write-Host "Found: $($extensionData.Name)" -ForegroundColor Green
                    }
                } catch {
                    Write-Host "Error processing Firefox extensions.json: $_" -ForegroundColor Red
                }
            }
        }
    } else {
        Write-Host "Firefox not found or no extensions installed." -ForegroundColor Yellow
    }
}

# Main execution starts here
Write-Host "Starting browser extensions scan..." -ForegroundColor Cyan

# Scan for Chrome extensions
$chromePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Extensions"
Get-ChromiumExtensions -BrowserName "Chrome" -BrowserPath $chromePath

# Scan for Edge extensions
$edgePath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Extensions"
Get-ChromiumExtensions -BrowserName "Edge" -BrowserPath $edgePath

# Scan for Firefox extensions
Get-FirefoxExtensions

# Export to JSON
if ($allExtensions.Count -gt 0) {
    $allExtensions | ConvertTo-Json -Depth 3 | Out-File -FilePath $outputFile -Encoding UTF8
    Write-Host "`nScan complete! Found $($allExtensions.Count) extensions." -ForegroundColor Cyan
    Write-Host "Results saved to: $outputFile" -ForegroundColor Green

    # Print extension IDs
    Write-Host "`nExtension IDs:" -ForegroundColor Magenta
    $allExtensions | ForEach-Object { Write-Host $_.ID }
} else {
    Write-Host "`nNo extensions found in any browser." -ForegroundColor Yellow
}
