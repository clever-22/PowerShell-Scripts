<#
.SYNOPSIS
    Disables or enables the Run dialog box (Win+R)
.DESCRIPTION
    Manages the NoRun registry value to control whether users can access the Run command.
    Note: This can affect UNC access in File Explorer. Supports get, set, and test operations.
#>

# Run this in System Context
# This can effect UNC in the file explorer
# You need to make a parameter: Enable with boolean as data type and default value false

$registryPath = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"
$valueName = "NoRun"

switch ($method) {
    "get" {
        if ($Enable) {
            $currentValue = Get-ItemProperty -Path $registryPath -Name $valueName -ErrorAction SilentlyContinue
            if ($currentValue -ne $null -and $currentValue.$valueName -eq 2) {
                return $true
            }
            $false
        }
        else {
            $currentValue = Get-ItemProperty -Path $registryPath -Name $valueName -ErrorAction SilentlyContinue
            if ($currentValue -ne $null -and $currentValue.$valueName -eq 1) {
                return $true
            }
            $false
        }
    }
    "set" {
         if ($Enable) {
            if (-not (Test-Path $registryPath)) {
                New-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies" -Name "Explorer" -Force
            }
            # Set the NoRun registry value to enable the Run dialog
            New-ItemProperty -Path $registryPath -Name $valueName -PropertyType DWORD -Value 2 -Force
            Write-Host "The Run dialog has been disabled. Log off or restart your computer for the changes to take effect."
        }
        else {
            if (-not (Test-Path $registryPath)) {
                New-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies" -Name "Explorer" -Force
            }
            # Set the NoRun registry value to disable the Run dialog
            New-ItemProperty -Path $registryPath -Name $valueName -PropertyType DWORD -Value 1 -Force
            Write-Host "The Run dialog has been disabled. Log off or restart your computer for the changes to take effect."
        }
        # Ensure the Explorer key exists
        
    }
    "test" {
        if ($Enable) {
            $currentValue = Get-ItemProperty -Path $registryPath -Name $valueName -ErrorAction SilentlyContinue
            if ($currentValue -ne $null -and $currentValue.$valueName -eq 2) {
                return $true
            }
            $false
        }
        else {
            $currentValue = Get-ItemProperty -Path $registryPath -Name $valueName -ErrorAction SilentlyContinue
            if ($currentValue -ne $null -and $currentValue.$valueName -eq 1) {
                return $true
            }
            $false
        }
    }
}