<#
.SYNOPSIS
    Displays a branded warning toast about a 10 PM restart.
.DESCRIPTION
    Downloads configured logo assets, registers a per-user toast application,
    and displays an informational Windows notification with website and
    dismiss actions. This script does not schedule or perform a restart.
#>

# Restart Warning Toast - Generic Branded Template
# Informational only. Does not schedule or perform the restart.
# Run as the logged-in USER (not SYSTEM) or the toast will not appear.

# ============================== SETTINGS ==============================
$appId        = 'YourCompany.Notifications'          # Unique ID, no spaces (e.g. 'Contoso.Notifications')
$displayName  = 'Your Company Name'                  # Name shown in the toast header
$websiteUrl   = 'https://www.yourcompany.com/'       # Site opened by the button / clicking the toast
$logoFolder   = 'C:\ProgramData\YourCompany'         # Local folder where logos are saved
$smallLogoUrl = 'https://www.yourcompany.com/small-logo.png'   # Square logo (~200x200) for the header icon
$heroLogoUrl  = 'https://www.yourcompany.com/banner-logo.jpg'  # Wide banner (~2:1, e.g. 728x360) for the top image

$title             = '⚠ Computer will Restart Tonight at 10pm'   # Bold title line
$message           = 'Please save your work and close any open applications before 10:00 PM. Your computer will restart automatically at that time.'  # Body text
$websiteButtonText = 'Visit Website'                 # Website button text
$dismissButtonText = 'OK'                            # Dismiss button text
# =====================================================================

$smallLogo = Join-Path $logoFolder 'small-logo.png'
$heroLogo  = Join-Path $logoFolder 'banner-logo.jpg'

# --- Download logos locally ---
if (-not (Test-Path $logoFolder)) { New-Item -Path $logoFolder -ItemType Directory -Force | Out-Null }
foreach ($logo in @(@{Url=$smallLogoUrl; Path=$smallLogo}, @{Url=$heroLogoUrl; Path=$heroLogo})) {
    if (-not (Test-Path $logo.Path)) {
        try { Invoke-WebRequest -Uri $logo.Url -OutFile $logo.Path -UseBasicParsing }
        catch { Write-Warning "Could not download $($logo.Url): $($_.Exception.Message)" }
    }
}

# --- Register custom AppID (header name + small icon) ---
$regPath = "HKCU:\Software\Classes\AppUserModelId\$appId"
if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
New-ItemProperty -Path $regPath -Name 'DisplayName'    -Value $displayName -PropertyType String -Force | Out-Null
New-ItemProperty -Path $regPath -Name 'IconUri'        -Value $smallLogo   -PropertyType String -Force | Out-Null
New-ItemProperty -Path $regPath -Name 'ShowInSettings' -Value 0            -PropertyType DWord  -Force | Out-Null

[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

# --- Escape text so characters like & < > don't break the XML ---
$xTitle   = [System.Security.SecurityElement]::Escape($title)
$xMessage = [System.Security.SecurityElement]::Escape($message)
$xWebBtn  = [System.Security.SecurityElement]::Escape($websiteButtonText)
$xDismiss = [System.Security.SecurityElement]::Escape($dismissButtonText)
$xUrl     = [System.Security.SecurityElement]::Escape($websiteUrl)

$toastXml = @"
<?xml version="1.0" encoding="utf-8"?>
<toast scenario="reminder" activationType="protocol" launch="$xUrl">
    <visual>
        <binding template="ToastGeneric">
            <text>$xTitle</text>
            <text>$xMessage</text>
        </binding>
    </visual>
    <actions>
        <action content="$xWebBtn" arguments="$xUrl" activationType="protocol"/>
        <action content="$xDismiss" arguments="dismiss" activationType="system"/>
    </actions>
</toast>
"@

try {
    $xmlDocument = New-Object Windows.Data.Xml.Dom.XmlDocument
    $xmlDocument.LoadXml($toastXml)

    # --- Add the banner logo as a hero image at the top of the toast ---
    if (Test-Path $heroLogo) {
        $binding = $xmlDocument.GetElementsByTagName('binding').Item(0)
        $image   = $xmlDocument.CreateElement('image')
        $image.SetAttribute('placement', 'hero')
        $image.SetAttribute('src', 'file:///' + ($heroLogo -replace '\\','/'))
        $binding.InsertBefore($image, $binding.FirstChild) | Out-Null
    }

    $toastNotification = New-Object Windows.UI.Notifications.ToastNotification($xmlDocument)
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show($toastNotification)

    Write-Host "Notification displayed successfully." -ForegroundColor Green
}
catch {
    Write-Error "Unable to display the notification: $($_.Exception.Message)"
}