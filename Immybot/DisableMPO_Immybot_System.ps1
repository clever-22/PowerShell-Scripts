#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Manages Multi-Plane Overlay (MPO) registry settings to resolve display flickers.
.DESCRIPTION
    Logic:
    - Compliance Check (Test): Returns $true if the registry state matches the desired $Enable parameter.
    - Remediation (Set): Applies the registry setting to force the desired state.
    - Reporting (Get): Returns the current status string.
.PARAMETER Enable
    $true  : Enables MPO (Reverts to Windows Default).
    $false : Disables MPO (Applies the Flicker Fix).
#>
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("get", "set", "test")]
    [string]$Method,
    [boolean]$Enable = $false
)

# Convert string to boolean if needed
if ($Enable -is [string]) {
    $Enable = [System.Convert]::ToBoolean($Enable)
}

$regPath  = "HKLM:\SOFTWARE\Microsoft\Windows\Dwm"
$regValue = "OverlayTestMode"

switch ($Method) {
    "get" {
        try {
            $value = (Get-ItemProperty -Path $regPath -Name $regValue -ErrorAction Stop).$regValue

            if ($Enable) {
                # Check if MPO is ENABLED (key should not exist or not equal 5)
                ($value -ne 5)
            }
            else {
                # Check if MPO is DISABLED (OverlayTestMode = 5)
                ($value -eq 5)
            }
        }
        catch {
            if ($Enable) {
                $true   # Key missing = MPO is enabled (default)
            }
            else {
                $false  # Key missing = MPO is not disabled
            }
        }
    }
    "set" {
        if ($Enable) {
            # RE-ENABLE MPO (remove the fix)
            if (Test-Path $regPath) {
                try {
                    Remove-ItemProperty -Path $regPath -Name $regValue -Force -ErrorAction Stop
                }
                catch {
                }
            }
        }
        else {
            # DISABLE MPO (apply the flicker fix)
            if (-not (Test-Path $regPath)) {
                New-Item -Path $regPath -Force | Out-Null
            }
            Set-ItemProperty -Path $regPath -Name $regValue -Value 5 -Type DWord -Force
        }
    }
    "test" {
        try {
            $value = (Get-ItemProperty -Path $regPath -Name $regValue -ErrorAction Stop).$regValue

            if ($Enable) {
                # Test if MPO is ENABLED (key should not exist or not equal 5)
                ($value -ne 5)
            }
            else {
                # Test if MPO is DISABLED (OverlayTestMode = 5)
                ($value -eq 5)
            }
        }
        catch {
            if ($Enable) {
                $true   # Key missing = MPO is enabled (default) = compliant
            }
            else {
                $false  # Key missing = MPO is not disabled = non-compliant
            }
        }
    }
}