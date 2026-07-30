# Restart Warning Toast
# Informational only. Does not schedule or perform the restart.

[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

$toastXml = @"
<?xml version="1.0" encoding="utf-8"?>
<toast scenario="reminder">
    <visual>
        <binding template="ToastGeneric">
            <text>⚠ Computer will Restart Tonight at 10pm</text>
            <text>Please save your work and close any open applications before 10:00 PM. Your computer will restart automatically at that time.</text>
        </binding>
    </visual>
    <actions>
        <action content="OK"
                arguments="dismiss"
                activationType="system"/>
    </actions>
</toast>
"@

try {
    $xmlDocument = New-Object Windows.Data.Xml.Dom.XmlDocument
    $xmlDocument.LoadXml($toastXml)

    $toastNotification = New-Object Windows.UI.Notifications.ToastNotification($xmlDocument)

    $appId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'

    $toastNotifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId)
    $toastNotifier.Show($toastNotification)

    Write-Host "Restart notification displayed successfully." -ForegroundColor Green
}
catch {
    Write-Error "Unable to display the notification: $($_.Exception.Message)"
}