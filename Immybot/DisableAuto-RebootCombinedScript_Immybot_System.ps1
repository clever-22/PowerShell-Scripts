<#
.SYNOPSIS
    Disables or enables automatic reboot when logged-on users are present
.DESCRIPTION
    Manages the NoAutoRebootWithLoggedOnUsers registry value to control whether
    Windows automatically restarts when users are logged in. Supports get, set, and test operations.
#>

# Run this in System Context
# You need to make a parameter: Enable with text as data type and default value true


# Convert string to boolean if needed
if ($Enable -is [string]) {
    $Enable = [System.Convert]::ToBoolean($Enable)
}

$regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
$regValue = "NoAutoRebootWithLoggedOnUsers"

switch ($Method) {
    "get" {
        try {
            $value = (Get-ItemProperty -Path $regPath -Name $regValue -ErrorAction Stop).$regValue
            
            if ($Enable) {
                # Check if auto-reboot is PREVENTED (NoAutoRebootWithLoggedOnUsers = 1)
                ($value -eq 1)
            }
            else {
                # Check if auto-reboot is ALLOWED (NoAutoRebootWithLoggedOnUsers = 0)
                ($value -eq 0)
            }
        }
        catch {
            if ($Enable) {
                $false  # Value doesn't exist = auto-reboot not prevented
            }
            else {
                $true  # Value doesn't exist = auto-reboot allowed (default)
            }
        }
    }
    "set" {
        if ($Enable) {
            # PREVENT auto-reboot with logged on users (NoAutoRebootWithLoggedOnUsers = 1)
            if (-not (Test-Path $regPath)) {
                New-Item -Path $regPath -Force | Out-Null
            }
            Set-ItemProperty -Path $regPath -Name $regValue -Value 1 -Type DWord -Force
        }
        else {
            # ALLOW auto-reboot (remove the value)
            if (Test-Path $regPath) {
                try {
                    Remove-ItemProperty -Path $regPath -Name $regValue -Force -ErrorAction Stop
                }
                catch {
                }
            }
        }
    }
    "test" {
        try {
            $value = (Get-ItemProperty -Path $regPath -Name $regValue -ErrorAction Stop).$regValue
            
            if ($Enable) {
                # Test if auto-reboot is PREVENTED
                ($value -eq 1)
            }
            else {
                # Test if auto-reboot is ALLOWED
                ($value -eq 0)
            }
        }
        catch {
            if ($Enable) {
                $false  # Value doesn't exist = not prevented
            }
            else {
                $true  # Value doesn't exist = allowed (default)
            }
        }
    }
}