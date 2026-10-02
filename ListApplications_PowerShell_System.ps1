<#
.SYNOPSIS
    Lists installed applications from the Windows registry.

.DESCRIPTION
    Queries the 32-bit and 64-bit uninstall registry keys, filters out entries without a display name,
    and outputs each installed application with its name, version, and publisher in a sorted list.
#>

Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*,
                 HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* |
Where-Object { $_.DisplayName } |
Select-Object DisplayName, DisplayVersion, Publisher |
Sort-Object DisplayName