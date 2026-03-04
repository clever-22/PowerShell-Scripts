<#
.SYNOPSIS
Disables Microsoft Teams Auto Start functionality.

.DESCRIPTION
This script manages the Teams auto-start setting in the Windows Registry. When the Enable parameter is set to $true, Teams will be disabled from auto-starting on system boot. When set to $false, Teams auto-start is enabled. The script supports get, set, and test methods to query, modify, or verify the Teams auto-start state.

.PARAMETER Enable
Determines whether Teams auto-start should be disabled ($true) or enabled ($false). This parameter is used across all operations to control the desired state of Teams startup behavior.
#>

$newTeamsRegistryPath = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\MSTeams_8wekyb3d8bbwe\TeamsTfwStartupTask"
$newTeamsRegistryValue = "State"

switch ($Method) {
    "get" {
        if ($Enable) {
            $currentValue = Get-ItemProperty -Path $newTeamsRegistryPath -Name $newTeamsRegistryValue -ErrorAction SilentlyContinue
            if ($currentValue -ne $null -and $currentValue.$newTeamsRegistryValue -eq 2) {
                return $true
            }
            return $false
        }
        else {
            $currentValue = Get-ItemProperty -Path $newTeamsRegistryPath -Name $newTeamsRegistryValue -ErrorAction SilentlyContinue
            if ($currentValue -ne $null -and $currentValue.$newTeamsRegistryValue -eq 0) {
                return $true
            }
            return $false
        }
    }
    "set" {
        if ($Enable) {
            if (-not (Test-Path $newTeamsRegistryPath)) {
                New-Item -Path $newTeamsRegistryPath -Force | Out-Null
            }
            Set-ItemProperty -Path $newTeamsRegistryPath -Name $newTeamsRegistryValue -Value 2 -Force
            $epoch = [int][double]::Parse((Get-Date -UFormat %s))
            Set-ItemProperty -Path $newTeamsRegistryPath -Name "LastDisabledTime" -Value $epoch -Force
        }
        else {
            if (-not (Test-Path $newTeamsRegistryPath)) {
                New-Item -Path $newTeamsRegistryPath -Force | Out-Null
            }
            Set-ItemProperty -Path $newTeamsRegistryPath -Name $newTeamsRegistryValue -Value 0 -Force
            $epoch = [int][double]::Parse((Get-Date -UFormat %s))
            Set-ItemProperty -Path $newTeamsRegistryPath -Name "LastDisabledTime" -Value $epoch -Force
        }
    }
    "test" {
        if ($Enable) {
            $currentValue = Get-ItemProperty -Path $newTeamsRegistryPath -Name $newTeamsRegistryValue -ErrorAction SilentlyContinue
            if ($currentValue -ne $null -and $currentValue.$newTeamsRegistryValue -eq 2) {
                return $true
            }
            return $false
        }
        else {
            $currentValue = Get-ItemProperty -Path $newTeamsRegistryPath -Name $newTeamsRegistryValue -ErrorAction SilentlyContinue
            if ($currentValue -ne $null -and $currentValue.$newTeamsRegistryValue -eq 0) {
                return $true
            }
            return $false
        }
    }
}