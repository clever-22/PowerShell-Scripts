# Pings Google till you stop it and then it will save it as a csv in the C drive
# Then you can open the file in excel and see when drops occur
$hostToPing = "8.8.8.8"
$logFile   = "C:\ping_log.csv"

if (-not (Test-Path $logFile)) {
    "Time,LatencyMs,Status" | Out-File $logFile
}

while ($true) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    try {
        $result = Test-Connection -ComputerName $hostToPing -Count 1 -ErrorAction Stop
        $latency = $result.ResponseTime
        $status  = "OK"
    } catch {
        $latency = ""
        $status  = "Timeout"
    }

    "$timestamp,$latency,$status" | Out-File -FilePath $logFile -Append

    Start-Sleep -Seconds 20
}