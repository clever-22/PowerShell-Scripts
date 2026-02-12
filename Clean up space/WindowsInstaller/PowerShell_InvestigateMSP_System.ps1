<#
.SYNOPSIS
    If you have a bunch of MSP Files that were installed on the same day you can change the day/time parameters to find correlating logs
.DESCRIPTION
    Analyzes MSP patch files created around a target time, extracts NTFS metadata,
    checks alternate data streams for download sources, and generates detailed report.
#>

# SYSTEM Context MSP Investigation Script
$installerFolder = "C:\Windows\Installer\"  # Change this to your actual path
$targetDate = Get-Date "1/22/2026 3:00 PM" # Change this to the specific time
$timeWindow = 2  # Hours before and after to search

# Create output file in a system-accessible location
$outputFile = "C:\Windows\Temp\MSP_Investigation_Report.txt"
"MSP File Download Investigation - $(Get-Date)" | Out-File $outputFile -Force
"Running as: $env:USERNAME" | Out-File $outputFile -Append
"=" * 80 | Out-File $outputFile -Append

$startTime = $targetDate.AddHours(-$timeWindow)
$endTime = $targetDate.AddHours($timeWindow)

# 1. Get MSP file details with NTFS metadata
"`n`n=== MSP FILES IN FOLDER ===" | Out-File $outputFile -Append
Get-ChildItem "$installerFolder\*.msp" -Force -ErrorAction SilentlyContinue | 
    Select-Object Name, CreationTime, LastWriteTime, LastAccessTime, 
                  @{Name="SizeMB";Expression={[math]::Round($_.Length/1MB,2)}},
                  @{Name="Owner";Expression={(Get-Acl $_.FullName).Owner}} | 
    Format-Table -AutoSize | 
    Out-File $outputFile -Append

# 2. Files created around target time with full metadata
"`n`n=== FILES CREATED AROUND $targetDate ===" | Out-File $outputFile -Append
Get-ChildItem "$installerFolder\*.msp" -Force -ErrorAction SilentlyContinue | 
    Where-Object { $_.CreationTime -ge $startTime -and $_.CreationTime -le $endTime } |
    ForEach-Object {
        $_ | Select-Object Name, CreationTime, LastWriteTime, 
                          @{Name="SizeMB";Expression={[math]::Round($_.Length/1MB,2)}},
                          @{Name="Owner";Expression={(Get-Acl $_.FullName).Owner}}
    } | Format-List | Out-File $outputFile -Append

# 3. Get Alternate Data Streams (Zone.Identifier shows download source)
"`n`n=== ALTERNATE DATA STREAMS (Download Sources) ===" | Out-File $outputFile -Append
Get-ChildItem "$installerFolder\*.msp" -Force -ErrorAction SilentlyContinue | 
    Where-Object { $_.CreationTime -ge $startTime -and $_.CreationTime -le $endTime } |
    ForEach-Object {
        $file = $_
        "`nFile: $($file.Name)" | Out-File $outputFile -Append
        try {
            $zoneId = Get-Content "$($file.FullName):Zone.Identifier" -ErrorAction SilentlyContinue
            if ($zoneId) {
                $zoneId | Out-File $outputFile -Append
            } else {
                "  No Zone.Identifier found" | Out-File $outputFile -Append
            }
        } catch {
            "  Unable to read Zone.Identifier" | Out-File $outputFile -Append
        }
    }

# 4. System Event Log - comprehensive
"`n`n=== SYSTEM EVENT LOG ===" | Out-File $outputFile -Append
try {
    Get-WinEvent -FilterHashtable @{
        LogName='System'
        StartTime=$startTime
        EndTime=$endTime
    } -ErrorAction Stop |
        Where-Object { 
            $_.Message -match "install|update|msp|download|msi|setup" 
        } |
        Select-Object TimeCreated, ProviderName, Id, LevelDisplayName, Message |
        Format-List |
        Out-File $outputFile -Append
} catch {
    "Error reading System log: $_" | Out-File $outputFile -Append
}

# 5. Application Event Log
"`n`n=== APPLICATION EVENT LOG ===" | Out-File $outputFile -Append
try {
    Get-WinEvent -FilterHashtable @{
        LogName='Application'
        StartTime=$startTime
        EndTime=$endTime
    } -ErrorAction Stop |
        Where-Object { 
            $_.Message -match "install|update|msp|download|msi|setup" 
        } |
        Select-Object TimeCreated, ProviderName, Id, LevelDisplayName, Message |
        Format-List |
        Out-File $outputFile -Append
} catch {
    "Error reading Application log: $_" | Out-File $outputFile -Append
}

# 6. Windows Update Client events
"`n`n=== WINDOWS UPDATE CLIENT EVENTS ===" | Out-File $outputFile -Append
try {
    Get-WinEvent -FilterHashtable @{
        LogName='System'
        ProviderName='Microsoft-Windows-WindowsUpdateClient'
        StartTime=$startTime
        EndTime=$endTime
    } -ErrorAction Stop |
        Select-Object TimeCreated, Id, LevelDisplayName, Message |
        Format-List |
        Out-File $outputFile -Append
} catch {
    "No Windows Update events found or error: $_" | Out-File $outputFile -Append
}

# 7. MSI Installer events
"`n`n=== MSI INSTALLER EVENTS ===" | Out-File $outputFile -Append
try {
    Get-WinEvent -FilterHashtable @{
        LogName='Application'
        ProviderName='MsiInstaller'
        StartTime=$startTime
        EndTime=$endTime
    } -ErrorAction Stop |
        Select-Object TimeCreated, Id, LevelDisplayName, Message |
        Format-List |
        Out-File $outputFile -Append
} catch {
    "No MSI Installer events found or error: $_" | Out-File $outputFile -Append
}

# 8. Task Scheduler Operational log
"`n`n=== SCHEDULED TASKS EXECUTED ===" | Out-File $outputFile -Append
try {
    Get-WinEvent -FilterHashtable @{
        LogName='Microsoft-Windows-TaskScheduler/Operational'
        StartTime=$startTime
        EndTime=$endTime
    } -ErrorAction Stop |
        Where-Object { $_.Id -eq 100 -or $_.Id -eq 102 -or $_.Id -eq 200 -or $_.Id -eq 201 } |
        Select-Object TimeCreated, Id, Message |
        Format-List |
        Out-File $outputFile -Append
} catch {
    "Error reading Task Scheduler log: $_" | Out-File $outputFile -Append
}

# 9. Service Control Manager events (services that started)
"`n`n=== SERVICES STARTED/STOPPED ===" | Out-File $outputFile -Append
try {
    Get-WinEvent -FilterHashtable @{
        LogName='System'
        ProviderName='Service Control Manager'
        StartTime=$startTime
        EndTime=$endTime
    } -ErrorAction Stop |
        Where-Object { $_.Id -eq 7036 -or $_.Id -eq 7040 } |
        Select-Object TimeCreated, Id, Message |
        Format-List |
        Out-File $outputFile -Append
} catch {
    "Error reading Service Control Manager log: $_" | Out-File $outputFile -Append
}

# 10. Check all user profile downloads folders
"`n`n=== CHECKING ALL USER DOWNLOAD FOLDERS ===" | Out-File $outputFile -Append
Get-ChildItem "C:\Users" -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
    $downloadPath = Join-Path $_.FullName "Downloads"
    if (Test-Path $downloadPath) {
        "`nUser: $($_.Name)" | Out-File $outputFile -Append
        Get-ChildItem "$downloadPath\*.msp" -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.CreationTime -ge $startTime -and $_.CreationTime -le $endTime } |
            Select-Object Name, CreationTime, @{Name="SizeMB";Expression={[math]::Round($_.Length/1MB,2)}} |
            Format-Table -AutoSize |
            Out-File $outputFile -Append
    }
}

# 11. Prefetch analysis
"`n`n=== PREFETCH FILES (Programs Run) ===" | Out-File $outputFile -Append
Get-ChildItem "C:\Windows\Prefetch\*.pf" -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -ge $startTime -and $_.LastWriteTime -le $endTime } |
    Select-Object Name, LastWriteTime, CreationTime |
    Format-Table -AutoSize |
    Out-File $outputFile -Append

# 12. Check Setup API logs
"`n`n=== SETUP API LOGS ===" | Out-File $outputFile -Append
$setupLogs = @(
    "C:\Windows\inf\setupapi.dev.log",
    "C:\Windows\inf\setupapi.app.log"
)
foreach ($log in $setupLogs) {
    if (Test-Path $log) {
        "`nLog: $log" | Out-File $outputFile -Append
        try {
            Get-Content $log -Tail 500 -ErrorAction SilentlyContinue |
                Select-String -Pattern "msp|install|update" -Context 2 |
                Out-File $outputFile -Append
        } catch {
            "Unable to read log" | Out-File $outputFile -Append
        }
    }
}

# 13. Windows Update logs (CBS)
"`n`n=== CBS/WINDOWS UPDATE LOGS ===" | Out-File $outputFile -Append
$cbsLog = "C:\Windows\Logs\CBS\CBS.log"
if (Test-Path $cbsLog) {
    try {
        Get-Content $cbsLog -Tail 1000 -ErrorAction SilentlyContinue |
            Select-String -Pattern "msp|$($targetDate.ToString('yyyy-MM-dd'))" |
            Select-Object -First 50 |
            Out-File $outputFile -Append
    } catch {
        "Unable to read CBS.log" | Out-File $outputFile -Append
    }
}

# 14. BITS transfer jobs
"`n`n=== BITS TRANSFER JOBS ===" | Out-File $outputFile -Append
try {
    Get-BitsTransfer -AllUsers -ErrorAction SilentlyContinue |
        Where-Object { $_.CreationTime -ge $startTime -and $_.CreationTime -le $endTime } |
        Select-Object DisplayName, JobState, CreationTime, BytesTotal, FileList |
        Format-List |
        Out-File $outputFile -Append
} catch {
    "Unable to query BITS transfers: $_" | Out-File $outputFile -Append
}

# 15. Process creation events (if auditing enabled)
"`n`n=== PROCESS CREATION EVENTS (Security Log) ===" | Out-File $outputFile -Append
try {
    Get-WinEvent -FilterHashtable @{
        LogName='Security'
        Id=4688
        StartTime=$startTime
        EndTime=$endTime
    } -ErrorAction Stop |
        Where-Object { 
            $_.Message -match "msiexec|setup|install|update|wusa" 
        } |
        Select-Object TimeCreated, Message |
        Select-Object -First 50 |
        Format-List |
        Out-File $outputFile -Append
} catch {
    "Process auditing not enabled or no events: $_" | Out-File $outputFile -Append
}

# Summary
"`n`n=== SUMMARY ===" | Out-File $outputFile -Append
"Report generated: $(Get-Date)" | Out-File $outputFile -Append
"Target time: $targetDate" | Out-File $outputFile -Append
"Search window: $startTime to $endTime" | Out-File $outputFile -Append
"Report location: $outputFile" | Out-File $outputFile -Append

Write-Host "Investigation complete!" -ForegroundColor Green
Write-Host "Report saved to: $outputFile" -ForegroundColor Cyan