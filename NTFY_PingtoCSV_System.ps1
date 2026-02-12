<#
.SYNOPSIS
    Monitors network connectivity with ping and logs results to CSV
.DESCRIPTION
    Periodically pings a target IP address and logs results to a CSV file.
    Tracks latency and packet loss, then uploads the log via ntfy.sh notification.
    Useful for monitoring network stability over extended periods.
#>

# ----------- User Configuration -----------

$targetIP        = "8.8.8.8"               # Host to ping
$runDurationMin  = 300                     # Total run duration in minutes (480 = 8 hours)
$intervalSeconds = 20                      # Ping every 20 seconds
$ntfyTopic       = "Insertyourtopicnamehere"      # Replace with your ntfy topic name
$ntfyServer      = "https://ntfy.sh"       # Base ntfy URL
$maxFileSizeMB   = 15                      # ntfy max attachment size (15 MB default)

$logPath = "$env:USERPROFILE\ping_monitor.csv"

# ----------- Initialization -----------

# Compute end time
$endTime = (Get-Date).AddMinutes($runDurationMin)

$totalPings = 0
$dropped     = 0

# Write CSV header if not present
if (-not (Test-Path $logPath)) {
    "Time,Status,LatencyMs" | Out-File $logPath
}

Write-Host "Monitoring $targetIP for $runDurationMin minutes until $endTime ..."

# ----------- Monitoring Loop -----------

while ((Get-Date) -lt $endTime) {

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $totalPings++

    try {
        $result = Test-Connection -ComputerName $targetIP -Count 1 -ErrorAction Stop
        $status  = "OK"
        $latency = $result.ResponseTime
    } catch {
        $status  = "Failed"
        $latency = ""
        $dropped++
    }

    "$timestamp,$status,$latency" | Out-File -Append -FilePath $logPath

    Start-Sleep -Seconds $intervalSeconds
}

Write-Host "Completed ($totalPings pings), Drops: $dropped"

# ----------- Send Summary and File to ntfy -----------

$uri = "$ntfyServer/$ntfyTopic"
$fileSizeMB = (Get-Item $logPath).Length / 1MB

Write-Host "Log file size: $([math]::Round($fileSizeMB, 2)) MB"

# Always send dropped packet info/summary first
Write-Host "Sending dropped packet info and summary..."

try {
    # Extract only failed pings from the CSV
    $droppedPackets = Import-Csv $logPath | Where-Object { $_.Status -eq "Failed" }
    
    # Build message with dropped packet details
    $message = "Ping monitor finished for $targetIP`n`n"
    $message += "📊 Summary:`n"
    $message += "Total pings: $totalPings`n"
    $message += "Dropped: $dropped`n"
    $message += "Drop rate: $([math]::Round(($dropped/$totalPings)*100, 2))%`n`n"
    
    if ($dropped -gt 0) {
        $message += "❌ Dropped Packet Times:`n"
        $message += "------------------------`n"
        foreach ($packet in $droppedPackets) {
            $message += "$($packet.Time)`n"
        }
    } else {
        $message += "✅ No packets dropped!"
    }
    
    $headers = @{
        "Title" = "Ping Monitor Complete - $targetIP"
        "Tags" = "chart_with_upwards_trend"
        "Priority" = "default"
    }
    
    $response = Invoke-RestMethod -Uri $uri -Method Post -Body $message -Headers $headers
    Write-Host "Summary and dropped packet info sent to ntfy topic '$ntfyTopic'."
} catch {
    Write-Warning "Could not send ntfy summary: $($_.Exception.Message)"
}

# Then send the file as attachment if it's small enough
if ($fileSizeMB -le $maxFileSizeMB) {
    Write-Host "Sending full log file as attachment..."
    
    try {
        $fileBytes = [System.IO.File]::ReadAllBytes($logPath)
        $fileName = "ping_monitor_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
        
        $headers = @{
            "Filename" = $fileName
            "Title" = "Ping Monitor Log File"
            "Tags" = "page_facing_up"
            "Message" = "Full log file attached"
        }
        
        $response = Invoke-RestMethod -Uri $uri -Method Post -Body $fileBytes -Headers $headers -ContentType "text/csv"
        Write-Host "Full log file sent to ntfy topic '$ntfyTopic'."
    } catch {
        Write-Warning "Could not send file attachment: $($_.Exception.Message)"
    }
} else {
    Write-Host "File too large ($([math]::Round($fileSizeMB, 2)) MB > $maxFileSizeMB MB). Skipping file attachment."
    
    try {
        $warningMsg = "⚠️ Full log file ($([math]::Round($fileSizeMB, 2)) MB) was too large to attach (max: $maxFileSizeMB MB).`nLog saved locally at: $logPath"
        
        $headers = @{
            "Title" = "Log File Too Large"
            "Tags" = "warning"
        }
        
        $response = Invoke-RestMethod -Uri $uri -Method Post -Body $warningMsg -Headers $headers
        Write-Host "File size warning sent to ntfy."
    } catch {
        Write-Warning "Could not send size warning: $($_.Exception.Message)"
    }
}

Write-Host "`nMonitoring complete. Log saved to: $logPath"