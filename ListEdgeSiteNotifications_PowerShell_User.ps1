$pref = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Preferences"

$notifications = (Get-Content $pref -Raw | ConvertFrom-Json).profile.content_settings.exceptions.notifications

$notifications.PSObject.Properties | ForEach-Object {
    [PSCustomObject]@{
        Site    = $_.Name
        Setting = switch ($_.Value.setting) { 1 {"Allow"} 2 {"Block"} default {$_.Value.setting} }
    }
}