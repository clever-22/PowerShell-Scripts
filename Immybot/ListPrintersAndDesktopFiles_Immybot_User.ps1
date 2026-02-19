<#
.SYNOPSIS
    Lists installed printers and files from user and public desktops
.DESCRIPTION
    Scans system for installed printers and retrieves file listings from both the current user's
    desktop and public desktop, sorted by last access time. Displays results in a formatted table.
#>

# Run this in User Context
Write-Output "`n*Printers*"
Get-Printer | Select-Object Name,PortName,Location | Out-String | Write-Output
Write-Output "*Desktop Files*`n"
Write-Output "-User-"
$userDesktopPath = [Environment]::GetFolderPath("Desktop")
Get-ChildItem -Path $userDesktopPath | Select-Object Basename,Extension,LastAccessTime | Sort-Object LastAccessTime -Descending | Out-String | Write-Output
Write-Output "-Public-"
Get-ChildItem -Path $env:Public\Desktop | Select-Object Basename,Extension,LastAccessTime | Sort-Object LastAccessTime -Descending | Out-String | Write-Output