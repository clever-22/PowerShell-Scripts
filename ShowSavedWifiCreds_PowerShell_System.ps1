<#
.SYNOPSIS
    Displays saved Wi-Fi network names and stored passwords.
.DESCRIPTION
    Enumerates saved WLAN profiles, retrieves their clear-text key content
    using netsh, and displays the credentials along with current Wi-Fi
    interface details. Run only on systems where credential access is authorized.
#>

(netsh wlan show profiles) |
Select-String "All User Profile" |
ForEach-Object {
    $SSID = ($_ -split ":")[1].Trim()
    $Pass = (netsh wlan show profile name="$SSID" key=clear |
        Select-String "Key Content").Line -replace '.*:\s*',''
    [PSCustomObject]@{
        SSID = $SSID
        Password = $Pass
    }
} | Format-Table -AutoSize

netsh wlan show interfaces