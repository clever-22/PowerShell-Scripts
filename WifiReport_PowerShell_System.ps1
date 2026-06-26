# Generate the report
netsh wlan show wlanreport

# Parse the HTML/XML output for nearby AP data
$reportPath = "$env:ProgramData\Microsoft\Windows\WlanReport\wlan-report-latest.html"

if (Test-Path $reportPath) {
    $content = Get-Content $reportPath -Raw
    
    # Extract BSSIDs and SSIDs from the report
    $bssidMatches = :Matches($content, '([0-9a-f]{2}:){5}[0-9a-f]{2}')
    $ssidMatches  = :Matches($content, 'SSID":"([^"]+)"')
    
    Write-Host "===== Networks from WLAN Report =====" -ForegroundColor Cyan
    Write-Host "BSSIDs found: $($bssidMatches.Count)"
    Write-Host "SSIDs found:  $($ssidMatches.Count)"
    
    # Open the full report
    Start-Process $reportPath
}