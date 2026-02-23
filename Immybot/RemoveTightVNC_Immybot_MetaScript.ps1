<#
.SYNOPSIS
    Removes TightVNC remote access software from the system.

.DESCRIPTION
    This MetaScript uninstalls TightVNC by stopping and disabling its service,
    removing program files from Program Files (x86), and clearing associated
    registry installer keys. Handles common TightVNC service name variations.
#>

# Stop and disable TightVNC service (handles common service names)
# Context is a MetaScript
Get-Service | Where-Object {
    $_.Name -match 'tvn|tightvnc'
} | ForEach-Object {
    if ($_.Status -ne 'Stopped') {
        Stop-Service -Name $_.Name -Force
    }
    Set-Service -Name $_.Name -StartupType Disabled
}

# Remove TightVNC program files
Remove-Item "C:\Program Files (x86)\TightVNC" -Recurse -Force -ErrorAction SilentlyContinue

# Remove installer registry keys
Remove-Item "HKCR:\Installer\Features\B836F4DA6689191458A0C5C265B2F2B3" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "HKCR:\Installer\Products\B836F4DA6689191458A0C5C265B2F2B3" -Recurse -Force -ErrorAction SilentlyContinue
