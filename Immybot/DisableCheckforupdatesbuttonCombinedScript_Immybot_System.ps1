<#
.SYNOPSIS
    Disables or enables the "Check for Updates" button in Windows settings
.DESCRIPTION
    Manages the SetDisableUXWUAccess registry value to hide or show the Windows Update UI elements.
    Supports get, set, and test operations.
#>

# Run this in System Context
# You need to make a parameter: Enable with text as data type and default value true

# Convert string to boolean if needed
if ($Enable -is [string]) {
    $Enable = [System.Convert]::ToBoolean($Enable)
}

$regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
$regValue = "SetDisableUXWUAccess"

switch ($Method) {
    "get" {
        try {
            $value = (Get-ItemProperty -Path $regPath -Name $regValue -ErrorAction Stop).$regValue
            
            if ($Enable) {
                ($value -eq 1)
            }
            else {
                ($value -eq 0)
            }
        }
        catch {
            if ($Enable) {
                $false
            }
            else {
                $true
            }
        }
    }
    "set" {
        if ($Enable) {
            if (-not (Test-Path $regPath)) {
                New-Item -Path $regPath -Force | Out-Null
            }
            Set-ItemProperty -Path $regPath -Name $regValue -Value 1 -Type DWord -Force
        }
        else {
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
                ($value -eq 1)
            }
            else {
                ($value -eq 0)
            }
        }
        catch {
            if ($Enable) {
                $false
            }
            else {
                $true
            }
        }
    }
}