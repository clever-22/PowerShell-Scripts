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