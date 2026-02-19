<#
.SYNOPSIS
    Searches for Chrysalis Backdoor / Lotus Blossom IOCs and sends alerts. Configured for the latest Notepad ++ Vulnerability in Feb 2026
.DESCRIPTION
    Scans system for file indicators (hashes and filenames) and network indicators
    associated with the Chrysalis Backdoor from Lotus Blossom's toolkit.
    Sends alerts to ntfy.sh when matches are found.
#>

# CONFIGURATION
$ntfyTopic = "Insertyourtopicnamehere"  # Change this to your ntfy topic
$ntfyServer = "https://ntfy.sh"  # Change if using self-hosted ntfy

# File indicators - Hash and Filename pairs
$FileIndicators = @(
    @{Name="update.exe"; Hash="a511be5164dc1122fb5a7daa3eef9467e43d8458425b15a640235796006590c9"},
    @{Name="[NSIS.nsi]"; Hash="8ea8b83645fba6e23d48075a0d3fc73ad2ba515b4536710cda4f1f232718f53e"},
    @{Name="BluetoothService.exe"; Hash="2da00de67720f5f13b17e9d985fe70f10f153da60c9ab1086fe58f069a156924"},
    @{Name="BluetoothService"; Hash="77bfea78def679aa1117f569a35e8fd1542df21f7e00e27f192c907e61d63a2e"},
    @{Name="log.dll"; Hash="3bdc4c0637591533f1d4198a72a33426c01f69bd2e15ceee547866f65e26b7ad"},
    @{Name="u.bat"; Hash="9276594e73cda1c69b7d265b3f08dc8fa84bf2d6599086b9acc0bb3745146600"},
    @{Name="conf.c"; Hash="f4d829739f2d6ba7e3ede83dad428a0ced1a703ec582fc73a4eee3df3704629a"},
    @{Name="libtcc.dll"; Hash="4a52570eeaf9d27722377865df312e295a7a23c3b6eb991944c2ecd707cc9906"},
    @{Name="admin"; Hash="831e1ea13a1bd405f5bda2b9d8f2265f7b1db6c668dd2165ccc8a9c4c15ea7dd"},
    @{Name="loader1"; Hash="0a9b8df968df41920b6ff07785cbfebe8bda29e6b512c94a3b2a83d10014d2fd"},
    @{Name="uffhxpSy"; Hash="4c2ea8193f4a5db63b897a2d3ce127cc5d89687f380b97a1d91e0c8db542e4f8"},
    @{Name="loader2"; Hash="e7cd605568c38bd6e0aba31045e1633205d0598c607a855e2e1bca4cca1c6eda"},
    @{Name="3yzr31vk"; Hash="078a9e5c6c787e5532a7e728720cbafee9021bfec4a30e3c2be110748d7c43c5"},
    @{Name="ConsoleApplication2.exe"; Hash="b4169a831292e245ebdffedd5820584d73b129411546e7d3eccf4663d5fc5be3"},
    @{Name="system"; Hash="7add554a98d3a99b319f2127688356c1283ed073a084805f14e33b4f6a6126fd"},
    @{Name="s047t5g.exe"; Hash="fcc2765305bcd213b7558025b2039df2265c3e0b6401e4833123c461df2de51a"}
)

# Network indicators
$NetworkIndicators = @{
    IPs = @("95.179.213.0", "61.4.102.97", "59.110.7.32", "124.222.137.114")
    Domains = @("api.skycloudcenter.com", "api.wiresguard.com")
}

# Search paths (customize as needed)
$SearchPaths = @(
    "$env:SystemRoot",
    "$env:ProgramFiles",
    "${env:ProgramFiles(x86)}",
    "$env:TEMP",
    "$env:LOCALAPPDATA",
    "$env:APPDATA",
    "$env:UserProfile\Downloads"
)

# Ensure C:\Temp directory exists
$reportDirectory = "C:\Temp"
if (-not (Test-Path $reportDirectory)) {
    try {
        New-Item -Path $reportDirectory -ItemType Directory -Force | Out-Null
        Write-Host "[*] Created directory: $reportDirectory" -ForegroundColor Green
    }
    catch {
        Write-Host "[!] Failed to create directory $reportDirectory : $_" -ForegroundColor Red
        Write-Host "[*] Falling back to current directory for reports" -ForegroundColor Yellow
        $reportDirectory = "."
    }
}

Write-Host "`n=== Chrysalis Backdoor IOC Scanner ===" -ForegroundColor Cyan
Write-Host "Starting scan at $(Get-Date)`n" -ForegroundColor Gray

# Function to calculate SHA256 hash
function Get-FileSHA256 {
    param([string]$FilePath)
    try {
        $hash = Get-FileHash -Path $FilePath -Algorithm SHA256 -ErrorAction Stop
        return $hash.Hash
    }
    catch {
        return $null
    }
}

# Function to send ntfy notification
function Send-NtfyAlert {
    param(
        [string]$Title,
        [string]$Message,
        [string]$Priority = "urgent",
        [string[]]$Tags = @("warning")
    )
    
    try {
        $headers = @{
            "Title" = $Title
            "Priority" = $Priority
            "Tags" = ($Tags -join ",")
        }
        
        $uri = "$ntfyServer/$ntfyTopic"
        Invoke-RestMethod -Uri $uri -Method Post -Body $Message -Headers $headers -ContentType "text/plain; charset=utf-8" -ErrorAction Stop
        Write-Host "    [✓] Alert sent to ntfy" -ForegroundColor Green
    }
    catch {
        Write-Host "    [!] Failed to send ntfy alert: $_" -ForegroundColor Red
    }
}

# Check for file indicators
Write-Host "[*] Checking for suspicious files..." -ForegroundColor Yellow
$foundFiles = @()
$exactHashMatches = @()

foreach ($path in $SearchPaths) {
    if (Test-Path $path) {
        Write-Host "    Scanning: $path" -ForegroundColor Gray
        
        foreach ($indicator in $FileIndicators) {
            # Search by filename
            $files = Get-ChildItem -Path $path -Filter $indicator.Name -Recurse -ErrorAction SilentlyContinue -Force
            
            foreach ($file in $files) {
                $fileHash = Get-FileSHA256 -FilePath $file.FullName
                
                if ($fileHash -eq $indicator.Hash) {
                    $exactHashMatches += [PSCustomObject]@{
                        Path = $file.FullName
                        Name = $indicator.Name
                        Hash = $fileHash
                        Match = "EXACT (Name + Hash)"
                    }
                    Write-Host "    [!] MATCH FOUND: $($file.FullName)" -ForegroundColor Red
                }
                elseif ($fileHash) {
                    $foundFiles += [PSCustomObject]@{
                        Path = $file.FullName
                        Name = $indicator.Name
                        Hash = $fileHash
                        Match = "Name only (Hash mismatch)"
                    }
                    Write-Host "    [!] Suspicious: $($file.FullName) (name match, different hash)" -ForegroundColor Yellow
                }
            }
        }
    }
}

# Check network indicators in various locations
Write-Host "`n[*] Checking for network indicators..." -ForegroundColor Yellow

# Check hosts file
$hostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
$hostsMatches = @()
if (Test-Path $hostsFile) {
    $hostsContent = Get-Content $hostsFile
    foreach ($domain in $NetworkIndicators.Domains) {
        if ($hostsContent -match $domain) {
            $hostsMatches += $domain
            Write-Host "    [!] Domain found in hosts file: $domain" -ForegroundColor Red
        }
    }
}

# Check DNS cache
$dnsMatches = @()
try {
    $dnsCache = Get-DnsClientCache -ErrorAction SilentlyContinue
    foreach ($domain in $NetworkIndicators.Domains) {
        $matchingEntries = $dnsCache | Where-Object { $_.Entry -like "*$domain*" }
        if ($matchingEntries) {
            $dnsMatches += $domain
            Write-Host "    [!] Domain found in DNS cache: $domain" -ForegroundColor Red
        }
    }
}
catch {
    Write-Host "    [i] Unable to check DNS cache" -ForegroundColor Gray
}

# Check active network connections
$activeConnections = @()
try {
    $connections = Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue
    foreach ($ip in $NetworkIndicators.IPs) {
        $connectionMatches = $connections | Where-Object { $_.RemoteAddress -eq $ip }
        if ($connectionMatches) {
            foreach ($match in $connectionMatches) {
                $activeConnections += [PSCustomObject]@{
                    LocalAddress = $match.LocalAddress
                    LocalPort = $match.LocalPort
                    RemoteAddress = $match.RemoteAddress
                    RemotePort = $match.RemotePort
                    State = $match.State
                }
            }
            Write-Host "    [!] ACTIVE CONNECTION to suspicious IP: $ip" -ForegroundColor Red
        }
    }
}
catch {
    Write-Host "    [i] Unable to check network connections" -ForegroundColor Gray
}

# Send ntfy alerts if matches found
if ($exactHashMatches.Count -gt 0 -or $dnsMatches.Count -gt 0 -or $activeConnections.Count -gt 0) {
    Write-Host "`n[*] Sending alert to ntfy..." -ForegroundColor Yellow
    
    $alertMessage = "🚨 CHRYSALIS BACKDOOR DETECTED on $env:COMPUTERNAME`n`n"
    
    # Add hash matches
    if ($exactHashMatches.Count -gt 0) {
        $alertMessage += "⚠️ EXACT HASH MATCHES: $($exactHashMatches.Count)`n"
        foreach ($match in $exactHashMatches) {
            $alertMessage += "  • $($match.Name)`n"
            $alertMessage += "    Path: $($match.Path)`n"
            $alertMessage += "    Hash: $($match.Hash.Substring(0,16))...`n"
        }
        $alertMessage += "`n"
    }
    
    # Add DNS cache matches
    if ($dnsMatches.Count -gt 0) {
        $alertMessage += "🌐 DNS CACHE MATCHES: $($dnsMatches.Count)`n"
        foreach ($domain in $dnsMatches) {
            $alertMessage += "  • $domain`n"
        }
        $alertMessage += "`n"
    }
    
    # Add active connections
    if ($activeConnections.Count -gt 0) {
        $alertMessage += "🔴 ACTIVE CONNECTIONS: $($activeConnections.Count)`n"
        foreach ($conn in $activeConnections) {
            $alertMessage += "  • $($conn.RemoteAddress):$($conn.RemotePort)`n"
        }
        $alertMessage += "`n"
    }
    
    $alertMessage += "Scan Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"
    $alertMessage += "`n⚠️ IMMEDIATE INVESTIGATION REQUIRED"
    
    # Determine severity
    $tags = @("warning", "computer", "security")
    $priority = "urgent"
    
    if ($exactHashMatches.Count -gt 0) {
        $tags += "rotating_light"
        $priority = "urgent"
    }
    
    # Send the alert
    Send-NtfyAlert -Title "🚨 Chrysalis Backdoor - $env:COMPUTERNAME" -Message $alertMessage -Priority $priority -Tags $tags
}

# Summary Report
Write-Host "`n=== SCAN RESULTS ===" -ForegroundColor Cyan
Write-Host "Scan completed at $(Get-Date)`n" -ForegroundColor Gray

Write-Host "File Indicators:" -ForegroundColor White
if ($foundFiles.Count -gt 0 -or $exactHashMatches.Count -gt 0) {
    if ($exactHashMatches.Count -gt 0) {
        Write-Host "`n  EXACT HASH MATCHES:" -ForegroundColor Red
        $exactHashMatches | Format-Table -AutoSize
    }
    if ($foundFiles.Count -gt 0) {
        Write-Host "`n  Name-only matches (different hashes):" -ForegroundColor Yellow
        $foundFiles | Format-Table -AutoSize
    }
    Write-Host "TOTAL EXACT MATCHES: $($exactHashMatches.Count)" -ForegroundColor Red
    Write-Host "TOTAL NAME MATCHES: $($foundFiles.Count)" -ForegroundColor Yellow
}
else {
    Write-Host "  No suspicious files found." -ForegroundColor Green
}

Write-Host "`nNetwork Indicators:" -ForegroundColor White
Write-Host "  Hosts file matches: $($hostsMatches.Count)" -ForegroundColor $(if($hostsMatches.Count -gt 0){"Red"}else{"Green"})
Write-Host "  DNS cache matches: $($dnsMatches.Count)" -ForegroundColor $(if($dnsMatches.Count -gt 0){"Red"}else{"Green"})
Write-Host "  Active connections: $($activeConnections.Count)" -ForegroundColor $(if($activeConnections.Count -gt 0){"Red"}else{"Green"})

if ($dnsMatches.Count -gt 0) {
    Write-Host "`n  DNS Cache Domains:" -ForegroundColor Red
    $dnsMatches | ForEach-Object { Write-Host "    • $_" -ForegroundColor Red }
}

if ($activeConnections.Count -gt 0) {
    Write-Host "`nActive Suspicious Connections:" -ForegroundColor Red
    $activeConnections | Format-Table -AutoSize
}

# Export results to C:\Temp
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$reportPath = Join-Path $reportDirectory "IOC_Scan_Results_$timestamp.txt"

$report = @"
=== Chrysalis Backdoor IOC Scan Report ===
Scan Date: $(Get-Date)
Computer: $env:COMPUTERNAME

EXACT Hash Matches: $($exactHashMatches.Count)
Name-only Matches: $($foundFiles.Count)
Hosts Matches: $($hostsMatches.Count)
DNS Matches: $($dnsMatches.Count)
Active Connections: $($activeConnections.Count)

=== EXACT HASH MATCHES ===
$($exactHashMatches | Format-Table | Out-String)

=== NAME-ONLY MATCHES ===
$($foundFiles | Format-Table | Out-String)

=== NETWORK DETAILS ===
Hosts: $($hostsMatches -join ', ')
DNS Cache: $($dnsMatches -join ', ')

=== ACTIVE CONNECTIONS ===
$($activeConnections | Format-Table | Out-String)
"@

try {
    $report | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Host "`n[*] Report saved to: $reportPath" -ForegroundColor Cyan
}
catch {
    Write-Host "`n[!] Failed to save report: $_" -ForegroundColor Red
}

if ($exactHashMatches.Count -gt 0 -or $dnsMatches.Count -gt 0 -or $activeConnections.Count -gt 0) {
    Write-Host "`n[!!!] POTENTIAL COMPROMISE DETECTED - INVESTIGATE IMMEDIATELY [!!!]" -ForegroundColor Red -BackgroundColor Black
    Write-Host "[!!!] Alert sent to ntfy topic: $ntfyTopic [!!!]" -ForegroundColor Red -BackgroundColor Black
}
else {
    Write-Host "`n[✓] No indicators of compromise detected." -ForegroundColor Green
    Write-Host "[i] No alert sent (no matches found)" -ForegroundColor Gray
}