<#
.SYNOPSIS
    Removes all temporary files from system temp folders
.DESCRIPTION
    This script cleans up temporary files from C:\Temp and C:\Windows\Temp directories.
    It recursively deletes all contents in these folders to free up disk space.
    Requires administrator privileges to execute successfully.
#>

# --- Define Absolute Paths ---
$CustomTemp = "C:\Temp"
$WinTemp    = "C:\Windows\Temp"

# --- Clean C:\Temp ---
if (Test-Path $CustomTemp) {
    Write-Host "Cleaning $CustomTemp..."
    Get-ChildItem -Path $CustomTemp -Recurse -ErrorAction SilentlyContinue | 
    Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
}

# --- Clean C:\Windows\Temp ---
if (Test-Path $WinTemp) {
    Write-Host "Cleaning $WinTemp..."
    Get-ChildItem -Path $WinTemp -Recurse -ErrorAction SilentlyContinue | 
    Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
}

Write-Host "Cleanup process complete."