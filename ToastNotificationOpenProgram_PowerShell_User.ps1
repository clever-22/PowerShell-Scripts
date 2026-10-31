<#
.SYNOPSIS
    Shows a toast notification with Calculator and File Explorer launchers.
.DESCRIPTION
    Builds a Windows toast notification for the logged-in user, creates helper
    scripts and command files in the temporary directory, and registers the
    notification actions for opening Calculator or File Explorer.
#>

# Custom Toast Notification with Calculator and File Explorer Launchers
# Based on SMBtotheCloud's toast notification guide

# Load required assemblies
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

# Define the toast notification XML
$toastXml = @"
<?xml version="1.0" encoding="utf-8"?>
<toast>
    <visual>
        <binding template="ToastGeneric">
            <text>Quick Launch</text>
            <text>Choose an application to open</text>
        </binding>
    </visual>
    <actions>
        <action content="Open Calculator" arguments="powershell://calc" activationType="protocol"/>
        <action content="Open File Explorer" arguments="powershell://explorer" activationType="protocol"/>
    </actions>
</toast>
"@

# Register protocol handler for custom actions
$protocolHandlerScript = @'
# Protocol Handler Script - Save this separately and register it
param([string]$action)

switch ($action) {
    "calc" {
        Start-Process "calc.exe"
    }
    "explorer" {
        Start-Process "explorer.exe"
    }
}
'@

# Alternative approach using direct PowerShell execution
# This creates a simpler toast that uses file:// protocol to execute PowerShell scripts

# Create helper scripts
$calcScript = @"
Start-Process "calc.exe"
"@

$explorerScript = @"
Start-Process "explorer.exe" -ArgumentList "C:\"
"@

# Save scripts to temp location
$tempPath = "$env:TEMP\ToastActions"
if (-not (Test-Path $tempPath)) {
    New-Item -Path $tempPath -ItemType Directory -Force | Out-Null
}

$calcScriptPath = "$tempPath\OpenCalc.ps1"
$explorerScriptPath = "$tempPath\OpenExplorer.ps1"

$calcScript | Out-File -FilePath $calcScriptPath -Encoding UTF8 -Force
$explorerScript | Out-File -FilePath $explorerScriptPath -Encoding UTF8 -Force

# Create batch files to execute the PowerShell scripts (more reliable)
$calcBatchPath = "$tempPath\OpenCalc.cmd"
$explorerBatchPath = "$tempPath\OpenExplorer.cmd"

@"
@echo off
powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File "$calcScriptPath"
"@ | Out-File -FilePath $calcBatchPath -Encoding ASCII -Force

@"
@echo off
powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File "$explorerScriptPath"
"@ | Out-File -FilePath $explorerBatchPath -Encoding ASCII -Force

# Updated toast XML using file protocol
$toastXmlWithFileProtocol = @"
<?xml version="1.0" encoding="utf-8"?>
<toast>
    <visual>
        <binding template="ToastGeneric">
            <text>Quick Launch</text>
            <text>Choose an application to open</text>
        </binding>
    </visual>
    <actions>
        <action content="Open Calculator" arguments="file:///$calcBatchPath" activationType="protocol"/>
        <action content="Open File Explorer" arguments="file:///$explorerBatchPath" activationType="protocol"/>
    </actions>
</toast>
"@

# SIMPLEST APPROACH: Direct application launch using built-in protocols
$simpleToastXml = @"
<?xml version="1.0" encoding="utf-8"?>
<toast>
    <visual>
        <binding template="ToastGeneric">
            <text>Quick Launch</text>
            <text>Choose an application to open</text>
        </binding>
    </visual>
    <actions>
        <action content="Open Calculator" arguments="calculator:" activationType="protocol"/>
        <action content="Open File Explorer" arguments="file:///C:/" activationType="protocol"/>
    </actions>
</toast>
"@

# Function to show toast notification
function Show-ToastNotification {
    param([string]$xmlContent)
    
    try {
        # Load the XML
        $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
        $xml.LoadXml($xmlContent)
        
        # Create the toast notification
        $toast = New-Object Windows.UI.Notifications.ToastNotification($xml)
        
        # Show the toast
        $appId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show($toast)
        
        Write-Host "Toast notification displayed successfully!" -ForegroundColor Green
    }
    catch {
        Write-Host "Error displaying toast: $_" -ForegroundColor Red
    }
}

# Display the toast notification (using simple approach)
Show-ToastNotification -xmlContent $simpleToastXml

# Optional: Display alternative version with batch files
# Uncomment the line below to use the batch file approach instead
# Show-ToastNotification -xmlContent $toastXmlWithFileProtocol