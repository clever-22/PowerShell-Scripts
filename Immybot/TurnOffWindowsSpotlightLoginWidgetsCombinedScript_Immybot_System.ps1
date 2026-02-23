# --- Functions ---
<#
.SYNOPSIS
    Tests if the lock screen settings are in the desired state.
.DESCRIPTION
    Checks the registry values for lock screen widgets and content delivery manager to see if they are set to the desired state (0).
.OUTPUTS
    Returns $true if all settings are correct, otherwise returns $false.
#>

# This runs as system

# Define registry keys and properties
$lockScreenKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Lock Screen'
$cdmKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
$properties = @{
    'LockScreenWidgetsEnabled'        = 0
    'RotatingLockScreenOverlayEnabled' = 0
    'SubscribedContent-338387Enabled'  = 0
    'SubscribedContent-338389Enabled'  = 0
}

function Test-LockScreenSettings {
    Write-Verbose "Testing lock screen settings..."
    $result = $true
    
    foreach ($property in $properties.Keys) {
        $path = if ($property -eq 'LockScreenWidgetsEnabled') { $lockScreenKey } else { $cdmKey }
        
        if (Test-Path -Path $path) {
            $currentValue = Get-ItemProperty -Path $path -Name $property -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $property
            if ($currentValue -ne $properties[$property]) {
                Write-Verbose "Failed test: '$property' is '$currentValue', expected '$($properties[$property])'."
                $result = $false
                break
            }
        } else {
            Write-Verbose "Failed test: Registry path '$path' does not exist."
            $result = $false
            break
        }
    }
    
    Write-Verbose "Test complete. Result: $result"
    return $result
}

<#
.SYNOPSIS
    Sets the lock screen settings to the desired state.
.DESCRIPTION
    Creates the necessary registry keys if they don't exist and sets the values for lock screen widgets and content delivery manager to 0.
#>
function Set-LockScreenSettings {
    Write-Verbose "Setting lock screen settings..."

    # Ensure registry keys exist
    if (-not (Test-Path $lockScreenKey)) { New-Item -Path $lockScreenKey -Force | Out-Null }
    if (-not (Test-Path $cdmKey)) { New-Item -Path $cdmKey -Force | Out-Null }
    
    # Set registry properties
    foreach ($property in $properties.Keys) {
        $path = if ($property -eq 'LockScreenWidgetsEnabled') { $lockScreenKey } else { $cdmKey }
        Set-ItemProperty -Path $path -Name $property -Type DWord -Value $properties[$property] -Force | Out-Null
    }
    
    Write-Verbose "Settings applied."
    Write-Host "Applied: Lock screen status set to None; fun facts/tips disabled."
    Write-Host "Please restart your computer for changes to take full effect."
}

<#
.SYNOPSIS
    Gets the current lock screen settings.
.DESCRIPTION
    Retrieves and displays the current values of the registry settings for the lock screen widgets and content delivery manager.
#>
function Get-LockScreenSettings {
    Write-Verbose "Getting current lock screen settings..."

    Write-Host "--- Current Lock Screen Settings ---"
    
    foreach ($property in $properties.Keys) {
        $path = if ($property -eq 'LockScreenWidgetsEnabled') { $lockScreenKey } else { $cdmKey }
        
        try {
            $value = (Get-ItemProperty -Path $path -Name $property -ErrorAction Stop).$property
            Write-Host "$path\$property`: $value"
        } catch {
            Write-Warning "Could not retrieve value for $property. Key or property might not exist."
        }
    }
}

# --- Script Execution ---

switch ($method) {
    "get" {
        Get-LockScreenSettings
    }
    "set" {
        Set-LockScreenSettings
    }
    "test" {
        $isCorrectlySet = Test-LockScreenSettings
        if ($isCorrectlySet) {
            Write-Host "✅ All lock screen settings are correctly configured."
        } else {
            Write-Host "❌ Lock screen settings are not in the desired state."
        }
        return $isCorrectlySet
    }
}