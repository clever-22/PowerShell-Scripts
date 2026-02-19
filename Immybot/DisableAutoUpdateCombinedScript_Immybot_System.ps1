<#
.SYNOPSIS
    Disables or enables automatic updates on Windows
.DESCRIPTION
    Manages the NoAutoUpdate registry value to control Windows Update behavior.
    Can disable automatic updates entirely or enable them with configurable options.
    Supports get, set, and test operations with automatic service restart.
#>

# Run this in System Context
# You need to make a parameter: Enable with text as data type and default value true


# Registry configuration
$regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
$regValue = "NoAutoUpdate"

# Debug output
Write-Host "Method: $Method"
Write-Host "Enable parameter: $Enable"

switch ($Method) {
    "get" {
        try {
            $value = (Get-ItemProperty -Path $regPath -Name $regValue -ErrorAction Stop).$regValue
            Write-Host "Registry value exists: $value"
            
            if ($Enable) {
                # Check if auto-update is DISABLED (NoAutoUpdate = 1)
                $result = ($value -eq 1)
                Write-Host "Checking if DISABLED: $result"
                return $result
            }
            else {
                # Check if auto-update is ENABLED (NoAutoUpdate = 0 or not set)
                $result = ($value -eq 0)
                Write-Host "Checking if ENABLED (value=0): $result"
                return $result
            }
        }
        catch {
            Write-Host "Registry value does NOT exist"
            
            if ($Enable) {
                Write-Host "Checking if DISABLED: False (value doesn't exist)"
                return $false  # Value doesn't exist = not disabled
            }
            else {
                Write-Host "Checking if ENABLED: True (default behavior)"
                return $true  # Value doesn't exist = enabled (default behavior)
            }
        }
    }
    "set" {
        if ($Enable) {
            # DISABLE auto-update (NoAutoUpdate = 1)
            Write-Host "DISABLING auto-update (setting NoAutoUpdate = 1)"
            if (-not (Test-Path $regPath)) {
                New-Item -Path $regPath -Force | Out-Null
            }
            Set-ItemProperty -Path $regPath -Name $regValue -Value 1 -Type DWord -Force
            Write-Host "NoAutoUpdate set to 1"
            
            # Optional: restart the Windows Update service
            Restart-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
            Write-Host "Windows Update service restarted"
        }
        else {
            # ENABLE auto-update (NoAutoUpdate = 0)
            Write-Host "ENABLING auto-update (setting NoAutoUpdate = 0)"
            if (-not (Test-Path $regPath)) {
                New-Item -Path $regPath -Force | Out-Null
            }
            Set-ItemProperty -Path $regPath -Name $regValue -Value 0 -Type DWord -Force
            Write-Host "NoAutoUpdate set to 0"
            
            # Optional: restart the Windows Update service
            Restart-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
            Write-Host "Windows Update service restarted"
        }
    }
    "test" {
        try {
            $value = (Get-ItemProperty -Path $regPath -Name $regValue -ErrorAction Stop).$regValue
            Write-Host "Registry value exists: $value"
            
            if ($Enable) {
                # Test if auto-update is DISABLED
                $result = ($value -eq 1)
                Write-Host "Testing if DISABLED: $result"
                return $result
            }
            else {
                # Test if auto-update is ENABLED
                $result = ($value -eq 0)
                Write-Host "Testing if ENABLED (value=0): $result"
                return $result
            }
        }
        catch {
            Write-Host "Registry value does NOT exist"
            
            if ($Enable) {
                Write-Host "Testing if DISABLED: False (value doesn't exist)"
                return $false  # Value doesn't exist = not disabled
            }
            else {
                Write-Host "Testing if ENABLED: True (default behavior)"
                return $true  # Value doesn't exist = enabled (default behavior)
            }
        }
    }
}