<#
.SYNOPSIS
    Displays all saved Wi-Fi network credentials
.DESCRIPTION
    Retrieves all saved Wi-Fi profiles on the system and displays the network name (SSID) 
    and password for each profile. 
#>

$profiles = netsh wlan show profiles

$ssids = $profiles | Where-Object { $_ -match "All User Profile\s*:\s*(.+)" } | ForEach-Object {
    $matches[1].Trim()
}

foreach ($ssid in $ssids) {
    Write-Host "`n--- $ssid ---"
    $profile = netsh wlan show profile name="$ssid" key=clear
    $keyLine = $profile | Where-Object { $_ -match "Key Content\s*:\s*(.+)" } | Select-Object -First 1
    if ($keyLine) {
        $password = ($keyLine -split ":\s*", 2)[1].Trim()
        Write-Host "Password: $password"
    } else {
        Write-Host "Password: Not found / Enterprise Wi-Fi"
    }
}