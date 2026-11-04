<#
.SYNOPSIS
Resets Windows Update services and cache folders.

.DESCRIPTION
Stops the Windows Update-related services, renames the SoftwareDistribution and
catroot2 cache folders, and then restarts the services. This can help resolve
Windows Update issues by forcing the caches to be rebuilt. Sends an ntfy alert when done.
#>

$NtfyTopic  = "Insertyourtopicnamehere"
$NtfyServer = "https://ntfy.sh"
$results    = @()

# Stop Windows Update services
Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
Stop-Service -Name bits -Force -ErrorAction SilentlyContinue
Stop-Service -Name cryptsvc -Force -ErrorAction SilentlyContinue
Stop-Service -Name msiserver -Force -ErrorAction SilentlyContinue

# Rename Windows Update cache folders
$ts = Get-Date -Format "yyyyMMdd-HHmmss"
foreach ($folder in "C:\Windows\SoftwareDistribution", "C:\Windows\System32\catroot2") {
    $name = Split-Path $folder -Leaf
    if (Test-Path $folder) {
        try {
            Rename-Item $folder "$name.old-$ts" -Force -ErrorAction Stop
            $results += "$name renamed OK"
        } catch {
            $results += "$name FAILED: $($_.Exception.Message)"
        }
    } else {
        $results += "$name not found"
    }
}

# Start services back up
Start-Service -Name cryptsvc -ErrorAction SilentlyContinue
Start-Service -Name bits -ErrorAction SilentlyContinue
Start-Service -Name wuauserv -ErrorAction SilentlyContinue
Start-Service -Name msiserver -ErrorAction SilentlyContinue

# Send ntfy notification
$failed = $results -match "FAILED"
$title  = if ($failed) { "WU Reset FAILED - $env:COMPUTERNAME" } else { "WU Reset Complete - $env:COMPUTERNAME" }
$tags   = if ($failed) { "x" } else { "white_check_mark" }
$body   = ($results -join "`n") + "`nFinished: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

Invoke-RestMethod -Uri "$NtfyServer/$NtfyTopic" -Method Post -Body $body -Headers @{
    Title    = $title
    Tags     = $tags
    Priority = if ($failed) { "high" } else { "default" }
}