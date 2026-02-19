<#
.SYNOPSIS
    Shows pending Windows updates and recent hotfixes
.DESCRIPTION
    Displays pending Windows updates and the 10 most recently installed hotfixes.
    Sends summary via ntfy.sh notification.
#>

# CONFIGURATION - CHANGE THIS!!!
$ntfyTopic = "Insertyourtopicnamehere"
$ntfyServer = "https://ntfy.sh"

$lines = @()

$updateSession  = New-Object -ComObject Microsoft.Update.Session
$updateSearcher = $updateSession.CreateUpdateSearcher()
$searchResult   = $updateSearcher.Search("IsInstalled=0 and IsHidden=0 and Type='Software'")

$lines += "Pending updates: $($searchResult.Updates.Count)"

foreach ($u in $searchResult.Updates) {
    $lines += " - $($u.Title)"
}

$lines += ""
$lines += "Latest installed hotfixes:"

Get-HotFix |
    Sort-Object InstalledOn -Descending |
    Select-Object -First 10 |
    ForEach-Object {
        $lines += "$($_.InstalledOn)  $($_.HotFixID)"
    }

$message = $lines -join "`n"
$hostname = $env:COMPUTERNAME

Invoke-RestMethod `
    -Uri "$ntfyServer/$ntfyTopic" `
    -Method Post `
    -Headers @{ Title = "$hostname - Windows Updates" } `
    -Body $message

 