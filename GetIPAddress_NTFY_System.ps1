<#
.SYNOPSIS
    Get public IP location and send to ntfy server.
#>

# ===== CONFIG =====
$ntfyServer = "https://ntfy.sh"           # change to your self-hosted URL if needed
$ntfyTopic  = "Insertyourtopicnamehere"     # change to your topic
$title      = "Device Location Report"
$priority   = "default"                   # min, low, default, high, max
$tags       = "round_pushpin,computer"    # emoji tags

# ===== GET LOCATION =====
try {
    $geo = Invoke-RestMethod -Uri "http://ip-api.com/json" -ErrorAction Stop |
        Select-Object query, city, regionName, country, lat, lon
}
catch {
    $errMsg = "Failed to get IP location: $($_.Exception.Message)"
    Invoke-RestMethod -Method Post -Uri "$ntfyServer/$ntfyTopic" `
        -Headers @{ "Title" = "Location Lookup Failed"; "Priority" = "high"; "Tags" = "warning" } `
        -Body $errMsg
    return
}

# ===== BUILD MESSAGE =====
$hostName = $env:COMPUTERNAME
$userName = $env:USERNAME
$time     = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

$message = @"
Host:    $hostName
User:    $userName
Time:    $time

Public IP: $($geo.query)
City:      $($geo.city)
Region:    $($geo.regionName)
Country:   $($geo.country)
Lat/Lon:   $($geo.lat), $($geo.lon)

Map: https://www.google.com/maps?q=$($geo.lat),$($geo.lon)
"@

# ===== SEND TO NTFY =====
try {
    Invoke-RestMethod -Method Post -Uri "$ntfyServer/$ntfyTopic" `
        -Headers @{
            "Title"    = $title
            "Priority" = $priority
            "Tags"     = $tags
            "Click"    = "https://www.google.com/maps?q=$($geo.lat),$($geo.lon)"
        } `
        -Body $message

    Write-Output "✅ Sent location to ntfy topic '$ntfyTopic'"
}
catch {
    Write-Output "❌ Failed to send to ntfy: $($_.Exception.Message)"
}