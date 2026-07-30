<#
.SYNOPSIS
    Shows pending Windows updates, recent hotfixes with real install times, and last reboot.
#>

# CONFIGURATION - CHANGE THIS!!!
$ntfyTopic  = "Insertyourtopicnamehere"
$ntfyServer = "https://ntfy.sh"

$lines = @()

# --- Pending Updates ---
$updateSession  = New-Object -ComObject Microsoft.Update.Session
$updateSearcher = $updateSession.CreateUpdateSearcher()
$searchResult   = $updateSearcher.Search("IsInstalled=0 and IsHidden=0 and Type='Software'")

$lines += "Pending updates: $($searchResult.Updates.Count)"
foreach ($u in $searchResult.Updates) {
    $lines += " - $($u.Title)"
}

# --- Last Reboot ---
$lastBoot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
$uptime   = (Get-Date) - $lastBoot
$lines += ""
$lines += "Last reboot: $($lastBoot.ToString('yyyy-MM-dd HH:mm:ss'))"
$lines += "Uptime: $([int]$uptime.TotalDays)d $($uptime.Hours)h $($uptime.Minutes)m"

# --- Recent Hotfixes with real install times ---
$lines += ""
$lines += "Latest installed hotfixes:"

# Pull WU client install-success events (System log, ID 19)
$wuEvents = Get-WinEvent -FilterHashtable @{
    LogName      = 'System'
    ProviderName = 'Microsoft-Windows-WindowsUpdateClient'
    ID           = 19
} -ErrorAction SilentlyContinue

$hotfixes = Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 10

foreach ($hf in $hotfixes) {
    $kb    = $hf.HotFixID
    $match = $wuEvents | Where-Object { $_.Message -match "\b$kb\b" } | Select-Object -First 1
    if ($match) {
        $installTime = $match.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss')
    } else {
        $installTime = $hf.InstalledOn.ToString('yyyy-MM-dd') + ' (date only)'
    }
    $lines += "$installTime  $kb"
}

# --- Send notification ---
$message  = $lines -join "`n"
$hostname = $env:COMPUTERNAME

Invoke-RestMethod `
    -Uri "$ntfyServer/$ntfyTopic" `
    -Method Post `
    -Headers @{ Title = "$hostname - Windows Updates" } `
    -Body $message